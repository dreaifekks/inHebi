import InHebiCore
import SwiftUI

struct ReadingSession: Identifiable, Hashable {
  let id = UUID()
  let pages: [URL]
  let albumID: String
  let referer: String
  let startPage: Int
}
@MainActor enum ReaderHistory {
  static var hintsShown = 0
}
struct ReaderView: View {
  let session: ReadingSession
  @State private var page: Int
  @AppStorage("reader.spread", store: TestMode.preferences) private var spread = false
  @AppStorage("reader.rightToLeft", store: TestMode.preferences) private var rightToLeft = true
  @State private var controls = false
  @State private var entryFocus: Focus = .thumbnail(0)
  @State private var pendingFocus: Focus?
  @State private var openingDirection: MoveCommandDirection?
  @State private var edgeQuietUntil = ContinuousClock.now
  @State private var ignoredEdgeEvents = 0
  @State private var closingDirection: MoveCommandDirection?
  @State private var reopenQuietUntil = ContinuousClock.now
  @State private var ignoredReopenEvents = 0
  @State private var visibleThumbnails: Set<Int> = []
  @State private var reload = 0
  @State private var hint = false
  @FocusState private var focus: Focus?
  @Environment(AppModel.self) private var appModel
  @Environment(\.dismiss) private var dismiss
  private enum Focus: Hashable {
    case canvas
    case thumbnail(Int)
    case resume
  }
  init(session: ReadingSession) {
    self.session = session
    _page = State(initialValue: min(session.startPage, max(0, session.pages.count - 1)))
  }
  private var indices: [Int] {
    ReaderLayout.visibleIndices(
      page: page, count: session.pages.count, spread: spread, rightToLeft: rightToLeft)
  }
  private var previewPage: Int { if case .thumbnail(let index) = focus { index } else { page } }
  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .bottom) {
        Color.black.ignoresSafeArea()
        ReaderPages(session: session, indices: indices, reload: reload, size: geometry.size)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .contentShape(Rectangle()).focusable(!controls).accessibilityElement(children: .contain)
          .focused($focus, equals: .canvas).accessibilityIdentifier("reader.canvas")
          .accessibilityLabel("第 \(page + 1) 页，共 \(session.pages.count) 页").focusEffectDisabled()
          .accessibilityValue(TestMode.enabled ? "ignored-reopen=\(ignoredReopenEvents)" : "")
          .onTapGesture { showControls() }
          .onMoveCommand { direction in
            if direction == .left { turn(forward: rightToLeft) }
            if direction == .right { turn(forward: !rightToLeft) }
            if direction == .down || direction == .up { showControls(direction: direction) }
          }
        if hint {
          Text(rightToLeft ? "← 下一页　上一页 →　·　按选择键显示选项" : "← 上一页　下一页 →　·　按选择键显示选项")
            .font(.system(size: 29)).padding(24).background(.regularMaterial, in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
            .accessibilityIdentifier("reader.hint")
        }
        VStack(alignment: .trailing, spacing: 22) {
          if controls {
            ScrollViewReader { proxy in
              ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 28) {
                  ForEach(session.pages.indices, id: \.self) { index in
                    VStack(spacing: 10) {
                      Button {
                        page = index
                        controls = false
                      } label: {
                        RemoteImage(
                          url: session.pages[index], referer: session.referer,
                          maxPixelSize: InHebiLayout.cardPixels
                        ).frame(width: 160, height: 213)
                      }.buttonStyle(.card).focused($focus, equals: .thumbnail(index))
                        .accessibilityIdentifier("reader.jump.\(index + 1)").accessibilityLabel(
                          "跳到第 \(index + 1) 页")
                      Text("\(index + 1)").font(.system(size: 25))
                    }.id(index)
                      .onScrollVisibilityChange { visible in
                        if visible { visibleThumbnails.insert(index) }
                        else { visibleThumbnails.remove(index) }
                        if visible && pendingFocus == .thumbnail(index) {
                          focus = .thumbnail(index)
                          pendingFocus = nil
                          FocusTrace.mark("reader visible-thumbnail-focus page=\(index + 1)")
                        }
                      }
                  }
                }.padding(30)
              }.focusSection().background(.regularMaterial)
                .onAppear {
                  proxy.scrollTo(page, anchor: .center)
                }
                .onChange(of: pendingFocus) { _, target in
                  if case .thumbnail(let index) = target {
                    proxy.scrollTo(index, anchor: .center)
                    if visibleThumbnails.contains(index) {
                      focus = target
                      pendingFocus = nil
                    }
                  }
                }
                .onMoveCommand { direction in
                  if direction == .up { closeControls(on: direction) }
                }
            }
            .frame(height: 313)
          }
          Text(pageLabel).font(.system(size: 22).monospacedDigit()).foregroundStyle(
            .white.opacity(0.75)
          )
          .accessibilityIdentifier("reader.page")
          .padding(.horizontal, 14).padding(.vertical, 6).background(
            .black.opacity(0.7), in: Capsule()
          )
          .padding(.trailing, 48)
          if controls {
            HStack(spacing: 28) {
              Button("下一页") { turn(forward: true) }.disabled(
                page + (spread ? 2 : 1) >= session.pages.count
              )
              .accessibilityIdentifier("reader.next")
              Button("上一页") { turn(forward: false) }.disabled(page == 0)
                .accessibilityIdentifier("reader.previous")
              Button(spread ? "切换单页" : "双页并排") { spread.toggle() }.accessibilityIdentifier(
                "reader.spread")
              Button("重试图片") { reload += 1 }.accessibilityIdentifier("reader.retry")
              Button("继续阅读") { controls = false }.focused($focus, equals: .resume)
                .accessibilityIdentifier("reader.resume")
                .task {
                  if pendingFocus == .resume {
                    focus = .resume
                    pendingFocus = nil
                  }
                }
              Button("关闭", action: close).accessibilityIdentifier("reader.close")
            }.padding(30).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
              .frame(maxWidth: .infinity).focusSection()
              .onMoveCommand { direction in
                if direction == .down { closeControls(on: direction) }
                if direction == .up { pendingFocus = .thumbnail(page) }
              }
          }
        }.frame(maxWidth: .infinity, alignment: .trailing).padding(.bottom, 32)
          .defaultFocus($focus, entryFocus)
          .accessibilityElement(children: .contain)
          .accessibilityIdentifier("reader.controls")
          .accessibilityValue(TestMode.enabled ? "ignored=\(ignoredEdgeEvents)" : "")
      }
    }.ignoresSafeArea()
      .toolbarVisibility(.hidden, for: .tabBar)
      .onAppear {
        appModel.readerActive = true
        focus = .canvas
        hint = ReaderHistory.hintsShown < 2
        ReaderHistory.hintsShown += 1
      }
      .task {
        try? await Task.sleep(for: .seconds(2.5))
        hint = false
      }
      .onDisappear {
        appModel.readerActive = false
        focus = nil
        appModel.saveReadingPage(page, album: session.albumID)
      }
      .onChange(of: controls) { _, value in
        FocusTrace.mark(
          "reader controls=\(value) page=\(page + 1) focus=\(String(describing: focus))")
        if !value {
          pendingFocus = nil
          visibleThumbnails.removeAll()
          focus = .canvas
        }
      }
      .onChange(of: focus) { old, new in
        FocusTrace.mark(
          "reader page=\(page + 1) focus=\(String(describing: old))->\(String(describing: new))")
      }
      .onChange(of: page) { _, value in appModel.updateReadingPage(value, album: session.albumID) }
      .onExitCommand { if controls { controls = false } else { close() } }
      .onPlayPauseCommand { if controls { controls = false } else { showControls() } }
      .task(id: "\(page)|\(spread)") {
        for index in ReaderLayout.prefetchIndices(
          page: page, count: session.pages.count, spread: spread)
        {
          if Task.isCancelled { return }
          _ = try? await ImageStore.shared.image(
            session.pages[index], referer: session.referer, maxPixelSize: InHebiLayout.readerPixels
          )
        }
      }
  }
  private var pageLabel: String {
    if controls { return "\(previewPage + 1) / \(session.pages.count)" }
    let last = min(session.pages.count, page + (spread ? 2 : 1))
    return spread && last > page + 1
      ? "\(page + 1)–\(last) / \(session.pages.count)" : "\(page + 1) / \(session.pages.count)"
  }
  private func showControls(
    direction: MoveCommandDirection? = nil, at now: ContinuousClock.Instant = .now
  ) {
    if let direction, direction == closingDirection, now < reopenQuietUntil {
      reopenQuietUntil = now.advanced(by: .milliseconds(350))
      ignoredReopenEvents += 1
      FocusTrace.mark("reader ignore-closing-burst count=\(ignoredReopenEvents)")
      return
    }
    closingDirection = nil
    entryFocus = direction == .down ? .resume : .thumbnail(page)
    pendingFocus = entryFocus
    openingDirection = direction
    let openedAt = now
    // Allow the initial panel layout/focus transition to finish before an edge
    // event from the opening swipe can dismiss it.
    edgeQuietUntil = openedAt.advanced(by: .seconds(1))
    ignoredEdgeEvents = 0
    controls = true
    FocusTrace.mark("reader open direction=\(String(describing: direction)) page=\(page + 1)")
    // XCUIRemote has no swipe API. Inject event times deterministically; async
    // sleeps on a busy UI thread cannot represent a 100ms remote event stream.
    if TestMode.enabled,
      ProcessInfo.processInfo.arguments.contains("--ui-reader-direction-burst"), let direction
    {
      for milliseconds in [100, 200, 900, 1100] {
        closeControls(on: direction, at: openedAt.advanced(by: .milliseconds(milliseconds)))
      }
    }
  }
  private func closeControls(
    on direction: MoveCommandDirection, at now: ContinuousClock.Instant = .now
  ) {
    FocusTrace.mark(
      "reader edge direction=\(direction) remaining=\(now.duration(to: edgeQuietUntil))")
    if direction == openingDirection && now < edgeQuietUntil {
      // Extend until this direction burst has been quiet for 350ms.
      edgeQuietUntil = max(edgeQuietUntil, now.advanced(by: .milliseconds(350)))
      ignoredEdgeEvents += 1
      FocusTrace.mark("reader ignore-opening-burst count=\(ignoredEdgeEvents)")
      return
    }
    closingDirection = direction
    reopenQuietUntil = now.advanced(by: .milliseconds(350))
    ignoredReopenEvents = 0
    controls = false
    if TestMode.enabled,
      ProcessInfo.processInfo.arguments.contains("--ui-reader-close-burst")
    {
      for milliseconds in [100, 300, 600] {
        showControls(direction: direction, at: now.advanced(by: .milliseconds(milliseconds)))
      }
    }
  }
  private func close() {
    focus = nil
    dismiss()
  }
  private func turn(forward: Bool) {
    page = ReaderLayout.advanced(
      page: page, count: session.pages.count, spread: spread, forward: forward)
  }
}

/// Fit both intrinsic widths to one height so the inner image edges meet exactly.
private struct ReaderPages: View {
  let session: ReadingSession
  let indices: [Int]
  let reload: Int
  let size: CGSize
  @State private var aspectRatios: [Int: CGFloat] = [:]

  var body: some View {
    let totalRatio = indices.reduce(CGFloat.zero) { $0 + (aspectRatios[$1] ?? 2 / 3) }
    let height = min(size.height, size.width / totalRatio)
    HStack(spacing: 0) {
      ForEach(indices, id: \.self) { index in
        RemoteImage(
          url: session.pages[index], referer: session.referer,
          maxPixelSize: InHebiLayout.readerPixels,
          onImageSizeChange: { aspectRatios[index] = $0.width / $0.height }
        ).id("\(index)-\(reload)")
          .frame(width: height * (aspectRatios[index] ?? 2 / 3), height: height)
          .accessibilityElement(children: .contain)
          .accessibilityIdentifier("reader.image.\(index + 1)")
      }
    }
  }
}
