import ShelfCore
import SwiftUI

enum BrowseFocus: Hashable {
  case card(String)
  case chip(String)
  case filter, search, strip
}
struct MediaEntry: Identifiable {
  let id: String
  let title: String
  let subtitle: String
  let cover: URL?
  let badge: String
  let fill: Bool
  init(_ video: Video) {
    id = video.id
    title = video.title
    cover = video.thumbnail
    subtitle = MediaText.joined([
      video.author, MediaText.date(video.createdAt),
      video.viewsText ?? MediaText.count(video.numViews).map { $0 + "次" },
    ])
    badge = MediaText.duration(video.duration)
    fill = video.isPortrait || !((video.height ?? 0) > (video.width ?? 0))
  }
  init(_ album: Album) {
    id = album.id
    title = album.title
    cover = album.cover
    fill = false
    badge = ""
    subtitle = MediaText.joined([album.pageCount.map { "\($0)P" }, album.createdAt])
  }
}
struct MediaGrid<Destination: View>: View {
  let entries: [MediaEntry]
  let width: CGFloat
  let portrait: Bool
  var comic = false
  var referer: String?
  let focus: FocusState<BrowseFocus?>.Binding
  var preparing: String?
  var quickError: String?
  var failedID: String?
  let destination: (String) -> Destination
  let quick: (String) -> Void
  @State private var loadedCovers = Set<String>()
  private var columns: Int { portrait ? ShelfLayout.portraitColumns : ShelfLayout.videoColumns }
  private var spacing: CGFloat { portrait ? ShelfLayout.portraitSpacing : ShelfLayout.videoSpacing }
  private var cardWidth: CGFloat { (width - CGFloat(columns - 1) * spacing) / CGFloat(columns) }
  private var imageHeight: CGFloat {
    portrait ? cardWidth * (comic ? 4 / 3 : 1.5) : cardWidth * 9 / 16
  }
  var body: some View {
    LazyVGrid(
      columns: Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing), count: columns),
      spacing: ShelfLayout.rowSpacing
    ) {
      ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
        VStack(alignment: .leading, spacing: ShelfLayout.coverTitleSpacing) {
          NavigationLink {
            destination(entry.id)
          } label: {
            ZStack(alignment: .bottomTrailing) {
              RemoteImage(
                url: entry.cover, referer: referer, maxPixelSize: ShelfLayout.cardPixels,
                fill: entry.fill,
                onLoadStateChange: { loaded in
                  if loaded { loadedCovers.insert(entry.id) } else { loadedCovers.remove(entry.id) }
                }
              )
              .frame(width: cardWidth, height: imageHeight).clipShape(
                RoundedRectangle(cornerRadius: ShelfLayout.cardRadius))
              if preparing == entry.id {
                Text(comic ? "正在打开…" : "准备播放…").font(ShelfLayout.captionFont).padding(10)
                  .background(.black.opacity(0.75))
              } else if !entry.badge.isEmpty {
                Text(entry.badge).font(.system(size: 23).monospacedDigit()).padding(.horizontal, 10)
                  .padding(.vertical, 6).background(.black.opacity(0.65), in: Capsule()).padding(10)
              }
            }
          }
          .buttonStyle(.card)
          .accessibilityLabel(entry.title)
          .accessibilityValue(loadedCovers.contains(entry.id) ? "封面已加载" : "封面加载中")
          .accessibilityIdentifier("\(comic ? "album" : "video").card.\(entry.id)")
          .focused(focus, equals: .card(entry.id))
          .onPlayPauseCommand { quick(entry.id) }

          VStack(alignment: .leading, spacing: 8) {
            Text(entry.title).font(ShelfLayout.titleFont).lineLimit(2).frame(
              height: 72, alignment: .topLeading
            )
            .accessibilityIdentifier("entry.title.\(entry.id)")
            Text(failedID == entry.id ? (quickError ?? "") : entry.subtitle)
              .font(ShelfLayout.captionFont).foregroundStyle(
                failedID == entry.id ? .orange : .secondary
              )
              .lineLimit(1).frame(height: 30, alignment: .topLeading)
          }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(width: cardWidth)
          .accessibilityElement(children: .contain).accessibilityIdentifier("entry.\(entry.id)")
          .id(entry.id)
      }
    }.scrollTargetLayout()
  }
}
struct FilterBar: View {
  let options: [SourceOption]
  @Binding var selection: String
  @Binding var focus: BrowseFocus?
  let controlFocus: FocusState<BrowseFocus?>.Binding
  let filterTitle: String?
  let filterAction: () -> Void
  let search: AnyView
  @State private var testBurst = 0
  @State private var injectedID: String?
  @State private var injectedRequest = 0
  var body: some View {
    HStack(spacing: 24) {
      ChipStrip(
        options: options, selection: selection, focus: $focus,
        injectedID: injectedID, injectedRequest: injectedRequest
      )
      .accessibilityIdentifier("filter.chips")
      .focused(controlFocus, equals: .strip)
      HStack(spacing: 24) {
        if let filterTitle {
          Button(action: filterAction) {
            HStack(spacing: FilterSymbols.spacing) {
              Image(systemName: FilterSymbols.control(filterTitle))
                .font(.system(size: FilterSymbols.pointSize, weight: .medium))
              Text(filterTitle).font(.system(size: 29)).lineLimit(1)
            }
          }.accessibilityLabel(filterTitle)
            .frame(maxWidth: .infinity).accessibilityIdentifier("filter.primary")
            .accessibilityValue(filterTitle).accessibilityHint("按下切换")
            .focused(controlFocus, equals: .filter)

        }
        search.focused(controlFocus, equals: .search)

      }.frame(width: filterTitle == nil ? 100 : ShelfLayout.filterFixedWidth)
    }.frame(height: ShelfLayout.filterHeight)
      .padding(.horizontal, ShelfLayout.horizontalInset).background(.regularMaterial)
      .onPlayPauseCommand(
        perform: TestMode.enabled
          && (ProcessInfo.processInfo.arguments.contains("--ui-fast-focus")
            || ProcessInfo.processInfo.arguments.contains("--ui-focus-before-down"))
          ? { testBurst += 1 } : nil
      )
      .task(id: testBurst) {
        guard testBurst > 0 else { return }
        // XCTest remote calls take ~0.5s each. Inject 100ms focus updates to exercise
        // the real view debounce + request path, separately from native key routing.
        if ProcessInfo.processInfo.arguments.contains("--ui-focus-before-down") {
          try? await Task.sleep(for: .milliseconds(200))
          injectedID = options[1].id
          injectedRequest += 1
          return
        }
        for option in options.dropFirst().prefix(3) {
          injectedID = option.id
          injectedRequest += 1
          do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
        }
      }
      .task(id: focus) {
        guard case .chip(let id) = focus, id != selection else { return }
        do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
        FocusTrace.mark("select-chip id=\(id)")
        selection = id
      }
  }
}
struct OptionSheet: View {
  let title: String
  let options: [SourceOption]
  @Binding var selection: String
  @FocusState private var focus: String?
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        List(options) { option in
          Button {
            selection = option.id
            dismiss()
          } label: {
            HStack {
              Text(option.title)
              Spacer()
              if selection == option.id { Image(systemName: "checkmark") }
            }
          }.focused($focus, equals: option.id).id(option.id).accessibilityIdentifier(
            "option.\(option.id)")
        }.navigationTitle(title).defaultFocus($focus, selection)
          .task {
            proxy.scrollTo(selection, anchor: .center)
            await Task.yield()
            focus = selection
          }
      }
    }
  }
}
struct LoadingFooter: View {
  let loading: Bool
  let error: String?
  let hasNext: Bool
  let retry: () -> Void
  var body: some View {
    VStack(spacing: 20) {
      if loading { ProgressView("正在加载下一页…") }
      if let error {
        Text(error).foregroundStyle(.orange)
        Button("重试", action: retry)
      } else if !loading && !hasNext {
        Text("已经到底了").font(ShelfLayout.captionFont).foregroundStyle(.secondary)
      }
    }.frame(maxWidth: .infinity).frame(minHeight: 80)
  }
}
