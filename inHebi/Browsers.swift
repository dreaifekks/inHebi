import InHebiCore
import SwiftUI

struct VideoBrowser: View {
  let source: any VideoSource
  let authRevision: Int
  var searchQuery: String?
  var filter: VideoFilter?
  var title: String?
  @State private var pager = Pager<Video>()
  @State private var chip: String
  @AppStorage private var sort: String
  @AppStorage private var rating: String
  @State private var showingFilter = false
  @State private var playback: VideoPlayback?
  @State private var preparing: String?
  @State private var quickError: String?
  @State private var failedID: String?
  init(
    source: any VideoSource, authRevision: Int = 0, searchQuery: String? = nil,
    filter: VideoFilter? = nil, title: String? = nil, initialCategory: String? = nil
  ) {
    self.source = source
    self.authRevision = authRevision
    self.searchQuery = searchQuery
    self.filter = filter
    self.title = title
    _chip = State(
      initialValue: source.categories.isEmpty
        ? source.sorts[0].id : (initialCategory ?? source.categories[0].id))
    _sort = AppStorage(
      wrappedValue: source.sorts[0].id, "\(source.name).sort", store: TestMode.preferences)
    _rating = AppStorage(
      wrappedValue: source.ratings.first?.id ?? "", "\(source.name).rating",
      store: TestMode.preferences)
  }
  private var hasBar: Bool { searchQuery == nil && filter == nil }
  private var key: String {
    "\(chip)|\(sort)|\(rating)|\(searchQuery ?? "")|\(String(describing: filter))|\(authRevision)"
  }
  var body: some View {
    BrowseList(
      traceScope: source.name,
      entries: pager.items.map(MediaEntry.init), portrait: pager.items.first?.isPortrait == true,
      emptyTitle: searchQuery.map { "没有找到「\($0)」" } ?? "这个分类暂时没有内容",
      hasBar: hasBar, options: source.categories.isEmpty ? source.sorts : source.categories,
      selection: $chip,
      filterTitle: source.categories.isEmpty
        ? "分级 · \(source.ratings.first { $0.id == rating }?.title ?? "")"
        : "排序 · \(source.sorts.first { $0.id == sort }?.title ?? "")",
      filterAction: changeFilter, key: key, loading: pager.loading, error: pager.error,
      hasNext: pager.next != nil, requestCount: pager.requestCount, loadedKey: pager.loadedKey,
      preparing: preparing, quickError: quickError, failedID: failedID,
      destination: { id in
        VideoDetail(source: source, id: id,
          cardMetadata: pager.items.first { $0.id == id }.map { LibraryMetadata(video: $0, source: source.name) })
      },
      search: {
        VideoSearchScreen(source: source, category: source.categories.isEmpty ? "" : chip)
      },
      quick: { id in Task { await quickPlay(id) } }, loadMore: { await load() }
    )
    .navigationTitle(title ?? "")
    .task(id: key) { await load(reset: true) }
    .sheet(isPresented: $showingFilter) {
      OptionSheet(title: "排序", options: source.sorts, selection: $sort)
    }
    .fullScreenCover(item: $playback) { PlayerScreen(playback: $0) }
  }
  private func changeFilter() {
    if source.categories.isEmpty {
      let index = source.ratings.firstIndex { $0.id == rating }!
      rating = source.ratings[(index + 1) % source.ratings.count].id
    } else {
      showingFilter = true
    }
  }
  private func load(reset: Bool = false) async {
    let sort = searchQuery != nil ? source.sorts[0].id : (source.categories.isEmpty ? chip : sort)
    let rating = rating
    let category = source.categories.isEmpty ? "" : chip
    let query = searchQuery ?? ""
    await pager.load(reset: reset, key: key, first: 0) { page in
      if let filter { return try await source.filteredVideos(filter, page: page) }
      let result = try await source.videos(
        page: page, sort: sort, rating: rating, query: query, category: category)
      if TestMode.enabled && ProcessInfo.processInfo.arguments.contains("--ui-slow-list") {
        try await Task.sleep(for: .seconds(2))
      }
      return result
    }
  }
  private func quickPlay(_ id: String) async {
    guard preparing == nil else { return }
    preparing = id
    failedID = nil
    quickError = nil
    defer { preparing = nil }
    do {
      let video = try await source.video(id: id)
      guard let stream = try await source.streams(for: video).first else {
        throw InHebiError.message("没有可播放的清晰度")
      }
      playback = VideoPlayback(video: video, stream: stream, sourceName: source.name,
        cardMetadata: pager.items.first { $0.id == id }.map { LibraryMetadata(video: $0, source: source.name) })
    } catch {
      failedID = id
      quickError = error.localizedDescription
      try? await Task.sleep(for: .seconds(3))
      failedID = nil
    }
  }
}

struct AlbumBrowser: View {
  @Environment(AppModel.self) private var model
  let source: any AlbumSource
  var searchQuery: String?
  var tag: String?
  @State private var pager = Pager<Album>()
  @State private var categories: [SourceOption] = []
  @State private var categoryError: String?
  @State private var category = ""
  @State private var reading: ReadingSession?
  @State private var preparing: String?
  @State private var quickError: String?
  @State private var failedID: String?
  private var key: String { "\(category)|\(searchQuery ?? "")|\(tag ?? "")" }
  var body: some View {
    BrowseList(
      traceScope: source.name,
      entries: pager.items.map(MediaEntry.init), portrait: true, comic: true,
      referer: source.imageReferer(albumID: nil),
      emptyTitle: searchQuery.map { "没有找到「\($0)」" } ?? "这个分类暂时没有内容",
      hasBar: searchQuery == nil && tag == nil,
      options: [SourceOption("", "最新")] + categories.flatMap(\.flattened),
      selection: $category, filterTitle: nil, filterAction: {}, key: key,
      loading: pager.loading, error: pager.error ?? categoryError,
      hasNext: pager.next != nil, requestCount: pager.requestCount, loadedKey: pager.loadedKey,
      preparing: preparing, quickError: quickError, failedID: failedID,
      destination: { AlbumDetail(source: source, id: $0) },
      search: { AlbumSearchScreen(source: source) },
      quick: { id in
        if let album = pager.items.first(where: { $0.id == id }) { Task { await quickRead(album) } }
      },
      loadMore: {
        if categoryError != nil { await loadCategories() } else { await load() }
      }
    )
    .task(id: key) { await load(reset: true) }
    .task { if categories.isEmpty { await loadCategories() } }
    .navigationDestination(item: $reading) { ReaderView(session: $0) }
  }
  private func loadCategories() async {
    do {
      categories = try await source.categories()
      categoryError = nil
    } catch let error as URLError where error.code == .cancelled {} catch is CancellationError {
    } catch { categoryError = error.localizedDescription }
  }
  private func load(reset: Bool = false) async {
    let category = category
    await pager.load(reset: reset, key: key, first: source.firstPage) {
      let result = try await source.albums(
        page: $0, category: category, query: searchQuery ?? "", tag: tag ?? "")
      if TestMode.enabled && ProcessInfo.processInfo.arguments.contains("--ui-slow-list") {
        try await Task.sleep(for: .seconds(2))
      }
      return result
    }
  }
  private func quickRead(_ album: Album) async {
    let id = album.id
    guard preparing == nil else { return }
    preparing = id
    failedID = nil
    defer { preparing = nil }
    do {
      let pages = try await source.pages(id: id)
      try model.library.recordVisit(LibraryMetadata(album: album, source: source.name))
      reading = ReadingSession(
        pages: pages, albumID: id, referer: source.imageReferer(albumID: id),
        startPage: model.lastReadingPage(id))
    } catch {
      failedID = id
      quickError = error.localizedDescription
      try? await Task.sleep(for: .seconds(3))
      failedID = nil
    }
  }
}
struct VideoSearchScreen: View {
  let source: any VideoSource
  let category: String
  @State private var text = ""
  @State private var submitted: String?
  var body: some View {
    VStack(spacing: 16) {
      TextField(category.isEmpty ? "搜索视频" : "在「\(category)」中搜索", text: $text)
        .submitLabel(.search).accessibilityIdentifier("search.input")
        .onSubmit {
          let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
          if !query.isEmpty { submitted = query }
        }
        .padding(.horizontal, InHebiLayout.horizontalInset).padding(.top, 20)
      if let submitted {
        VideoBrowser(source: source, searchQuery: submitted, initialCategory: category)
      } else {
        ContentUnavailableView("输入关键词后完成搜索", systemImage: "magnifyingglass").frame(
          maxHeight: .infinity)
      }
    }.ignoresSafeArea(.container, edges: .horizontal)
      .accessibilityElement(children: .contain).accessibilityIdentifier("search.screen")
  }
}
struct AlbumSearchScreen: View {
  let source: any AlbumSource
  @State private var text = ""
  @State private var submitted: String?
  var body: some View {
    VStack(spacing: 16) {
      TextField("搜索漫画", text: $text).submitLabel(.search).accessibilityIdentifier("search.input")
        .onSubmit {
          let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
          if !query.isEmpty { submitted = query }
        }
        .padding(.horizontal, InHebiLayout.horizontalInset).padding(.top, 20)
      if let submitted {
        AlbumBrowser(source: source, searchQuery: submitted)
      } else {
        ContentUnavailableView("输入关键词后完成搜索", systemImage: "magnifyingglass").frame(
          maxHeight: .infinity)
      }
    }.ignoresSafeArea(.container, edges: .horizontal)
      .accessibilityElement(children: .contain).accessibilityIdentifier("search.screen")
  }
}
