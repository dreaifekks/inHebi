import SwiftUI
import ShelfCore

struct VideoBrowser: View {
    let source: any VideoSource
    let authRevision: Int
    var searchQuery: String?
    var filter: VideoFilter?
    var title: String?
    @State private var pager = Pager<Video>()
    @AppStorage private var sort: String
    @AppStorage private var rating: String
    @AppStorage private var category: String
    @FocusState private var focus: BrowseFocus?
    @State private var savedCard: String?
    @State private var scrollAnchor: String?
    @State private var showingFilter = false
    @State private var playback: VideoPlayback?
    @State private var preparing: String?
    @State private var quickError: String?
    @State private var failedID: String?
    init(source: any VideoSource, authRevision: Int = 0, searchQuery: String? = nil, filter: VideoFilter? = nil, title: String? = nil) {
        self.source = source; self.authRevision = authRevision; self.searchQuery = searchQuery; self.filter = filter; self.title = title
        _sort = AppStorage(wrappedValue: source.sorts[0].id, "\(source.name).sort", store: TestMode.preferences)
        _rating = AppStorage(wrappedValue: source.ratings.first?.id ?? "", "\(source.name).rating", store: TestMode.preferences)
        _category = AppStorage(wrappedValue: "", "\(source.name).category", store: TestMode.preferences)
    }
    private var hasBar: Bool { searchQuery == nil && filter == nil }
    private var key: String { "\(sort)|\(rating)|\(category)|\(searchQuery ?? "")|\(String(describing: filter))|\(authRevision)" }
    private var portrait: Bool { pager.items.first?.isPortrait == true }
    private var columns: Int { portrait ? ShelfLayout.portraitColumns : ShelfLayout.videoColumns }
    private var chipSelection: Binding<String> { source.categories.isEmpty ? $sort : $category }
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 20).id("top")
                        if pager.items.isEmpty {
                            if pager.loading { ProgressView("加载中…").frame(height: 500) }
                            else if pager.error == nil { ContentUnavailableView(searchQuery.map { "没有找到「\($0)」" } ?? "这个分类暂时没有内容", systemImage: "magnifyingglass").frame(height: 500) }
                        }
                        MediaGrid(entries: pager.items.map(MediaEntry.init), width: geometry.size.width - 2 * ShelfLayout.horizontalInset, portrait: portrait, focus: $focus, preparing: preparing, quickError: quickError, failedID: failedID,
                                  destination: { VideoDetail(source: source, id: $0) }, quick: { id in Task { await quickPlay(id) } }, appeared: { index in
                            if index >= pager.items.count - columns * 2 { Task { await load() } }
                        })
                        LoadingFooter(loading: pager.loading && !pager.items.isEmpty, error: pager.error, hasNext: pager.next != nil) { Task { await load() } }
                    }.padding(.horizontal, ShelfLayout.horizontalInset)
                }
                .scrollPosition(id: $scrollAnchor)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if hasBar {
                        FilterBar(options: source.categories.isEmpty ? source.sorts : source.categories, selection: chipSelection, focus: $focus,
                                  filterTitle: source.categories.isEmpty ? "分级 · \(source.ratings.first { $0.id == rating }?.title ?? "")" : "排序 · \(source.sorts.first { $0.id == sort }?.title ?? "")",
                                  filterAction: changeFilter,
                                  search: AnyView(NavigationLink { VideoSearchScreen(source: source, category: category) } label: { Image(systemName: "magnifyingglass").font(.system(size: 29)) }.accessibilityIdentifier("search.open")))
                    }
                }
                .onChange(of: key) { _, _ in savedCard = nil; scrollAnchor = nil; proxy.scrollTo("top", anchor: .top) }
                .onChange(of: focus) { _, new in if case .card(let id) = new { savedCard = id } }
                .task(id: key) {
                    let restoring = pager.loadedKey == key && !pager.items.isEmpty
                    await load(reset: true)
                    if restoring, let savedCard { await Task.yield(); focus = .card(savedCard) }
                }
                .overlay(alignment: .bottomTrailing) { if TestMode.enabled { Text("count=\(pager.items.count);requests=\(pager.requestCount)").font(.system(size: 12)).accessibilityIdentifier("browse.metrics") } }
            }
        }
        .ignoresSafeArea(.container, edges: .horizontal)
        .navigationTitle(title ?? "")
        .sheet(isPresented: $showingFilter) { OptionSheet(title: "排序", options: source.sorts, selection: $sort) }
        .fullScreenCover(item: $playback, onDismiss: { if let savedCard { focus = .card(savedCard) } }) { PlayerScreen(playback: $0) }
    }
    private func changeFilter() {
        if source.categories.isEmpty {
            let index = source.ratings.firstIndex { $0.id == rating }!
            rating = source.ratings[(index + 1) % source.ratings.count].id
        } else { showingFilter = true }
    }
    private func load(reset: Bool = false) async {
        let sort = sort, rating = rating, category = category, query = searchQuery ?? ""
        await pager.load(reset: reset, key: key, first: 0) { page in
            if let filter { return try await source.filteredVideos(filter, page: page) }
            return try await source.videos(page: page, sort: searchQuery == nil ? sort : source.sorts[0].id, rating: rating, query: query, category: category)
        }
    }
    private func quickPlay(_ id: String) async {
        guard preparing == nil else { return }
        preparing = id; failedID = nil; quickError = nil
        defer { preparing = nil }
        do {
            let video = try await source.video(id: id)
            guard let stream = try await source.streams(for: video).first else { throw ShelfError.message("没有可播放的清晰度") }
            playback = VideoPlayback(video: video, stream: stream)
        } catch { failedID = id; quickError = error.localizedDescription; try? await Task.sleep(for: .seconds(3)); failedID = nil }
    }
}

struct AlbumBrowser: View {
    let source: any AlbumSource
    var searchQuery: String?
    var tag: String?
    @State private var pager = Pager<Album>()
    @State private var categories: [SourceOption] = []
    @State private var categoryError: String?
    @AppStorage("wnacg.category", store: TestMode.preferences) private var category = ""
    @AppStorage("wnacg.subcategory", store: TestMode.preferences) private var subcategory = ""
    @FocusState private var focus: BrowseFocus?
    @State private var savedCard: String?
    @State private var scrollAnchor: String?
    @State private var showingFilter = false
    @State private var reading: ReadingSession?
    @State private var preparing: String?
    @State private var quickError: String?
    @State private var failedID: String?
    private var hasBar: Bool { searchQuery == nil && tag == nil }
    private var children: [SourceOption] { categories.first { $0.id == category }?.children ?? [] }
    private var key: String { "\(category)|\(subcategory)|\(searchQuery ?? "")|\(tag ?? "")" }
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 20).id("top")
                        if pager.items.isEmpty {
                            if pager.loading { ProgressView("加载中…").frame(height: 500) }
                            else if pager.error == nil { ContentUnavailableView(searchQuery.map { "没有找到「\($0)」" } ?? "这个分类暂时没有内容", systemImage: "books.vertical").frame(height: 500) }
                        }
                        if let categoryError { Text(categoryError).foregroundStyle(.orange); Button("重试分类") { Task { await loadCategories() } } }
                        MediaGrid(entries: pager.items.map(MediaEntry.init), width: geometry.size.width - 2 * ShelfLayout.horizontalInset, portrait: true, comic: true, referer: source.imageReferer(albumID: nil), focus: $focus, preparing: preparing, quickError: quickError, failedID: failedID,
                                  destination: { AlbumDetail(source: source, id: $0) }, quick: { id in Task { await quickRead(id) } }, appeared: { index in
                            if index >= pager.items.count - ShelfLayout.portraitColumns * 2 { Task { await load() } }
                        })
                        LoadingFooter(loading: pager.loading && !pager.items.isEmpty, error: pager.error, hasNext: pager.next != nil) { Task { await load() } }
                    }.padding(.horizontal, ShelfLayout.horizontalInset)
                }
                .scrollPosition(id: $scrollAnchor)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if hasBar {
                        FilterBar(options: [SourceOption("", "最新")] + categories,
                                  selection: Binding(get: { category }, set: { category = $0; subcategory = "" }), focus: $focus,
                                  filterTitle: category.isEmpty ? nil : "子类 · \(children.first { $0.id == subcategory }?.title ?? "全部")",
                                  filterAction: { showingFilter = true },
                                  search: AnyView(NavigationLink { AlbumSearchScreen(source: source) } label: { Image(systemName: "magnifyingglass").font(.system(size: 29)) }.accessibilityIdentifier("search.open")))
                    }
                }
                .onChange(of: key) { _, _ in savedCard = nil; scrollAnchor = nil; proxy.scrollTo("top", anchor: .top) }
                .onChange(of: focus) { _, new in if case .card(let id) = new { savedCard = id } }
                .task(id: key) {
                    let restoring = pager.loadedKey == key && !pager.items.isEmpty
                    await load(reset: true)
                    if restoring, let savedCard { await Task.yield(); focus = .card(savedCard) }
                }
                .task { if categories.isEmpty { await loadCategories() } }
                .overlay(alignment: .bottomTrailing) { if TestMode.enabled { Text("count=\(pager.items.count);requests=\(pager.requestCount)").font(.system(size: 12)).accessibilityIdentifier("browse.metrics") } }
            }
        }.ignoresSafeArea(.container, edges: .horizontal)
        .sheet(isPresented: $showingFilter) { OptionSheet(title: "子类", options: [SourceOption("", "全部")] + children, selection: $subcategory) }
        .fullScreenCover(item: $reading, onDismiss: { if let savedCard { focus = .card(savedCard) } }) { ReaderView(session: $0) }
    }
    private func loadCategories() async {
        do { categories = try await source.categories(); categoryError = nil }
        catch let error as URLError where error.code == .cancelled { }
        catch is CancellationError { }
        catch { categoryError = error.localizedDescription }
    }
    private func load(reset: Bool = false) async {
        let selected = subcategory.isEmpty ? category : subcategory
        await pager.load(reset: reset, key: key, first: source.firstPage) { try await source.albums(page: $0, category: selected, query: searchQuery ?? "", tag: tag ?? "") }
    }
    private func quickRead(_ id: String) async {
        guard preparing == nil else { return }
        preparing = id; failedID = nil
        defer { preparing = nil }
        do { reading = ReadingSession(pages: try await source.pages(id: id), albumID: id, referer: source.imageReferer(albumID: id), startPage: ReaderHistory.lastPage(id)) }
        catch { failedID = id; quickError = error.localizedDescription; try? await Task.sleep(for: .seconds(3)); failedID = nil }
    }
}

struct VideoSearchScreen: View {
    let source: any VideoSource
    let category: String
    @State private var text = ""
    @State private var submitted: String?
    var body: some View {
        Group {
            if let submitted { VideoBrowser(source: source, searchQuery: submitted) }
            else { ContentUnavailableView("搜索视频", systemImage: "magnifyingglass") }
        }
        .searchable(text: $text, prompt: category.isEmpty ? "搜索视频" : "在「\(category)」中搜索")
        .onSubmit(of: .search) { submitted = text.trimmingCharacters(in: .whitespacesAndNewlines) }
        .accessibilityIdentifier("search.screen")
    }
}
struct AlbumSearchScreen: View {
    let source: any AlbumSource
    @State private var text = ""
    @State private var submitted: String?
    var body: some View {
        Group {
            if let submitted { AlbumBrowser(source: source, searchQuery: submitted) }
            else { ContentUnavailableView("搜索漫画", systemImage: "magnifyingglass") }
        }.searchable(text: $text, prompt: "搜索漫画")
            .onSubmit(of: .search) { submitted = text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .accessibilityIdentifier("search.screen")
    }
}
