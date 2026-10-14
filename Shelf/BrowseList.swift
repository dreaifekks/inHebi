import ShelfCore
import SwiftUI

/// One focus/scroll owner shared by video and album lists.
struct BrowseList<Destination: View, Search: View>: View {
  let entries: [MediaEntry]
  let portrait: Bool
  var comic = false
  var referer: String?
  var emptyTitle = "这个分类暂时没有内容"
  let hasBar: Bool
  let options: [SourceOption]
  @Binding var selection: String
  let filterTitle: String?
  let filterAction: () -> Void
  let key: String
  let loading: Bool
  let error: String?
  let hasNext: Bool
  let requestCount: Int
  let loadedKey: String?
  var preparing: String?
  var quickError: String?
  var failedID: String?
  let destination: (String) -> Destination
  let search: () -> Search
  let quick: (String) -> Void
  let loadMore: () async -> Void
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @FocusState private var focus: BrowseFocus?
  @State private var position = ScrollPosition(idType: String.self)
  @State private var visible = false
  @State private var nearBottom = false
  @State private var offset: CGFloat = 0
  private var columns: Int { portrait ? ShelfLayout.portraitColumns : ShelfLayout.videoColumns }
  private var focusedIndex: Int? {
    guard case .card(let id) = focus else { return nil }
    return entries.firstIndex { $0.id == id }
  }
  private var focusedNearEnd: Bool {
    guard let index = focusedIndex else { return false }
    return index >= entries.count - columns * 2
  }
  private var gridFocused: Bool { if case .card = focus { true } else { false } }
  private var paginationDemand: String { "\(key)|\(entries.count)|\(nearBottom)|\(focusedNearEnd)" }
  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        if hasBar {
          FilterBar(
            options: options, selection: $selection, focus: $focus,
            filterTitle: filterTitle, filterAction: filterAction,
            search: AnyView(
              NavigationLink(destination: search) {
                Image(systemName: "magnifyingglass").font(.system(size: 29))
              }.accessibilityIdentifier("search.open")))
        }
        ScrollView {
          VStack(spacing: 0) {
            Color.clear.frame(height: 20)
            if entries.isEmpty {
              if loading {
                ProgressView("加载中…").frame(height: 500)
              } else if error == nil {
                ContentUnavailableView(
                  emptyTitle, systemImage: comic ? "books.vertical" : "magnifyingglass"
                ).frame(height: 500)
              }
            }
            MediaGrid(
              entries: entries, width: geometry.size.width - 2 * ShelfLayout.horizontalInset,
              portrait: portrait, comic: comic, referer: referer, focus: $focus,
              preparing: preparing, quickError: quickError, failedID: failedID,
              destination: destination, quick: quick,
              firstRowUp: { index in
                if hasBar {
                  focus =
                    index == columns - 1
                    ? (filterTitle == nil ? .search : .filter) : .chip(selection)
                }
              })
            LoadingFooter(loading: loading && !entries.isEmpty, error: error, hasNext: hasNext) {
              Task { await loadMore() }
            }.accessibilityIdentifier("browse.footer")
          }.padding(.horizontal, ShelfLayout.horizontalInset)
        }
        .scrollPosition($position)
        .onScrollGeometryChange(for: Viewport.self) { geometry in
          Viewport(
            offset: geometry.contentOffset.y,
            nearBottom: geometry.visibleRect.maxY >= geometry.contentSize.height - 700)
        } action: { _, value in
          offset = value.offset
          nearBottom = value.nearBottom
        }
        .onExitCommand(
          perform: gridFocused
            ? {
              if hasBar {
                position.scrollTo(y: 0)
                focus = .chip(selection)
              } else {
                dismiss()
              }
            } : nil)
      }
      .background {
        if hasBar { TabFocusEntry { if visible { focus = .chip(selection) } } }
      }
      .onAppear { visible = true }
      .onDisappear { visible = false }
      .onChange(of: key) { _, _ in position.scrollTo(y: 0) }
      .onChange(of: paginationDemand, initial: true) { _, _ in
        if case .card = focus,
          !entries.isEmpty && loadedKey == key && hasNext && error == nil
            && (nearBottom || focusedNearEnd)
        {
          Task { await loadMore() }
        }
      }
      .overlay(alignment: .bottomTrailing) {
        if TestMode.enabled {
          Text(
            verbatim:
              "count=\(entries.count);requests=\(requestCount);selection=\(selection);key=\(loadedKey ?? "");offset=\(Int(offset));index=\(focusedIndex ?? -1);loading=\(loading)"
          )
          .font(.system(size: 12)).accessibilityIdentifier("browse.metrics")
        }
      }
    }.ignoresSafeArea(.container, edges: .horizontal)
      .toolbarVisibility(model.readerActive ? .hidden : .visible, for: .tabBar)
  }
  private struct Viewport: Equatable {
    let offset: CGFloat
    let nearBottom: Bool
  }
}
