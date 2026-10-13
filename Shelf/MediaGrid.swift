import ShelfCore
import SwiftUI

enum BrowseFocus: Hashable {
  case card(String)
  case chip(String)
  case filter, search
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
  let namespace: Namespace.ID
  let preferredCard: String?
  var preparing: String?
  var quickError: String?
  var failedID: String?
  let destination: (String) -> Destination
  let quick: (String) -> Void
  let appeared: (Int) -> Void
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
        VStack(alignment: .leading, spacing: 12) {
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
          .prefersDefaultFocus(preferredCard == entry.id, in: namespace)
          .onPlayPauseCommand { quick(entry.id) }
          VStack(alignment: .leading, spacing: 8) {
            Text(entry.title).font(ShelfLayout.titleFont).lineLimit(2).frame(
              height: 72, alignment: .topLeading)
            Text(failedID == entry.id ? (quickError ?? "") : entry.subtitle)
              .font(ShelfLayout.captionFont).foregroundStyle(
                failedID == entry.id ? .orange : .secondary
              )
              .lineLimit(1).frame(height: 30, alignment: .topLeading)
          }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("entry.\(entry.id)")
        .id(entry.id)
        .onAppear { appeared(index) }
      }
    }.scrollTargetLayout()
  }
}
struct FilterBar: View {
  let options: [SourceOption]
  @Binding var selection: String
  let focus: FocusState<BrowseFocus?>.Binding
  let filterTitle: String?
  let filterAction: () -> Void
  let search: AnyView
  var body: some View {
    HStack(spacing: 18) {
      ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 16) {
            ForEach(options) { option in
              Button {
                selection = option.id
              } label: {
                HStack(spacing: 8) {
                  if selection == option.id { Image(systemName: "checkmark") }
                  Text(option.title)
                }.font(.system(size: 29)).padding(.horizontal, 12).frame(height: 40)
              }
              .buttonStyle(.borderedProminent).tint(
                selection == option.id ? .cyan : Color(white: 0.2)
              )
              .accessibilityAddTraits(selection == option.id ? .isSelected : [])
              .accessibilityIdentifier("chip.\(option.id)")
              .focused(focus, equals: .chip(option.id)).id(option.id)
            }
          }.padding(.horizontal, 8).padding(.vertical, 12)
        }
        .overlay(alignment: .trailing) {
          LinearGradient(
            colors: [.clear, .black.opacity(0.35)], startPoint: .leading, endPoint: .trailing
          ).frame(width: 60).allowsHitTesting(false)
        }
        .focusSection()
        .onAppear { if !selection.isEmpty { proxy.scrollTo(selection, anchor: .center) } }
        .onChange(of: focus.wrappedValue) { _, value in
          if case .chip(let id) = value { proxy.scrollTo(id, anchor: .center) }
        }
        .onMoveCommand { direction in
          guard case .chip(let id) = focus.wrappedValue,
            let index = options.firstIndex(where: { $0.id == id })
          else { return }
          if direction == .right {
            focus.wrappedValue =
              index + 1 < options.count
              ? .chip(options[index + 1].id) : (filterTitle == nil ? .search : .filter)
          } else if direction == .left && index > 0 {
            focus.wrappedValue = .chip(options[index - 1].id)
          }
        }
      }
      HStack(spacing: 16) {
        Rectangle().fill(.secondary.opacity(0.3)).frame(width: 1, height: 40)
        if let filterTitle {
          Button(filterTitle, action: filterAction).font(.system(size: 29))
            .frame(maxWidth: .infinity).accessibilityIdentifier("filter.primary")
            .accessibilityValue(filterTitle).accessibilityHint("按下切换")
            .focused(focus, equals: .filter)
        } else {
          Spacer()
        }
        search.focused(focus, equals: .search)
      }.frame(width: ShelfLayout.filterFixedWidth).focusSection()
    }.frame(height: ShelfLayout.filterHeight)
      .padding(.horizontal, ShelfLayout.horizontalInset).background(.regularMaterial)
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
      if loading { ProgressView() }
      if let error {
        Text(error).foregroundStyle(.orange)
        Button("重试", action: retry)
      } else if !loading && !hasNext {
        Text("已经到底了").font(ShelfLayout.captionFont).foregroundStyle(.secondary)
      }
    }.frame(maxWidth: .infinity).frame(minHeight: 80)
  }
}
