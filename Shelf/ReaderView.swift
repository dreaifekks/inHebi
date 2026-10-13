import ShelfCore
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
  static func lastPage(_ album: String) -> Int {
    TestMode.preferences.integer(forKey: "reader.lastPage.\(album)")
  }
  static func save(_ page: Int, album: String) {
    let defaults = TestMode.preferences
    var recent = defaults.stringArray(forKey: "reader.recent") ?? []
    recent.removeAll { $0 == album }
    recent.insert(album, at: 0)
    for old in recent.dropFirst(50) { defaults.removeObject(forKey: "reader.lastPage.\(old)") }
    defaults.set(Array(recent.prefix(50)), forKey: "reader.recent")
    defaults.set(page, forKey: "reader.lastPage.\(album)")
  }
}
struct ReaderView: View {
  let session: ReadingSession
  @State private var page: Int
  @AppStorage("reader.spread", store: TestMode.preferences) private var spread = false
  @AppStorage("reader.rightToLeft", store: TestMode.preferences) private var rightToLeft = true
  @State private var controls = false
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
    let values = ReaderLayout.visibleIndices(page: page, count: session.pages.count, spread: spread)
    return rightToLeft ? values : values.reversed()
  }
  private var previewPage: Int { if case .thumbnail(let index) = focus { index } else { page } }
  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .bottom) {
        Color.black.ignoresSafeArea()
        HStack(spacing: 6) {
          ForEach(indices, id: \.self) { index in
            RemoteImage(
              url: session.pages[index], referer: session.referer,
              maxPixelSize: ShelfLayout.readerPixels
            ).id("\(index)-\(reload)")
              .frame(
                width: spread ? (geometry.size.width - 6) / 2 : geometry.size.width,
                height: geometry.size.height)
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
          .contentShape(Rectangle()).focusable(!controls).accessibilityElement(children: .contain)
          .focused($focus, equals: .canvas).accessibilityIdentifier("reader.canvas")
          .accessibilityLabel("第 \(page + 1) 页，共 \(session.pages.count) 页").focusEffectDisabled()
          .onTapGesture { controls = true }
          .onMoveCommand { direction in
            if direction == .left { turn(forward: rightToLeft) }
            if direction == .right { turn(forward: !rightToLeft) }
            if direction == .down || direction == .up { controls = true }
          }
        if hint {
          Text(rightToLeft ? "← 下一页　上一页 →　·　按选择键显示选项" : "← 上一页　下一页 →　·　按选择键显示选项")
            .font(.system(size: 29)).padding(24).background(.regularMaterial, in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
            .accessibilityIdentifier("reader.hint")
        }
        VStack(spacing: 22) {
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
                          maxPixelSize: ShelfLayout.cardPixels
                        ).frame(width: 160, height: 213)
                      }.buttonStyle(.card).focused($focus, equals: .thumbnail(index))
                        .accessibilityIdentifier("reader.jump.\(index + 1)").accessibilityLabel(
                          "跳到第 \(index + 1) 页")
                      Text("\(index + 1)").font(.system(size: 25))
                    }.id(index)
                  }
                }.padding(30)
              }.focusSection().background(.regularMaterial)
                .onAppear {
                  proxy.scrollTo(page, anchor: .center)
                  focus = .thumbnail(page)
                }
            }
            .frame(height: 313)
          }
          Text(pageLabel).font(.callout.monospacedDigit()).accessibilityIdentifier("reader.page")
            .padding(.horizontal, 18).padding(.vertical, 8).background(
              .black.opacity(0.7), in: Capsule())
          if controls {
            HStack(spacing: 28) {
              Button("下一页") { turn(forward: true) }.disabled(
                page + (spread ? 2 : 1) >= session.pages.count)
              Button("上一页") { turn(forward: false) }.disabled(page == 0)
              Button(spread ? "切换单页" : "双页并排") { spread.toggle() }.accessibilityIdentifier(
                "reader.spread")
              Button("重试图片") { reload += 1 }
              Button("继续阅读") { controls = false }.focused($focus, equals: .resume)
              Button("关闭", action: close)
            }.padding(30).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
              .frame(maxWidth: .infinity).focusSection()
          }
        }.padding(.bottom, 32)
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
        ReaderHistory.save(page, album: session.albumID)
      }
      .onChange(of: controls) { _, value in if !value { focus = .canvas } }
      .onExitCommand { if controls { controls = false } else { close() } }
      .onPlayPauseCommand { controls.toggle() }
      .task(id: "\(page)|\(spread)") {
        let start = page + (spread ? 2 : 1)
        let end = min(session.pages.count, page + 6)
        if start < end {
          for index in start..<end {
            if Task.isCancelled { return }
            _ = try? await ImageStore.shared.image(
              session.pages[index], referer: session.referer, maxPixelSize: ShelfLayout.readerPixels
            )
          }
        }
      }
  }
  private var pageLabel: String {
    if controls { return "\(previewPage + 1) / \(session.pages.count)" }
    let last = min(session.pages.count, page + (spread ? 2 : 1))
    return spread && last > page + 1
      ? "\(page + 1)–\(last) / \(session.pages.count)" : "\(page + 1) / \(session.pages.count)"
  }
  private func close() {
    ReaderHistory.save(page, album: session.albumID)
    focus = nil
    dismiss()
  }
  private func turn(forward: Bool) {
    page = ReaderLayout.advanced(
      page: page, count: session.pages.count, spread: spread, forward: forward)
  }
}
