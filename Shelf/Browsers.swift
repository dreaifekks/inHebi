import SwiftUI
import ShelfCore

struct VideoBrowser: View {
    let source: any VideoSource
    let authRevision: Int
    @State private var pager = Pager<Video>()
    @State private var sort: String
    @State private var rating: String
    @State private var category = ""
    @State private var searchText = ""
    @State private var query = ""
    init(source: any VideoSource, authRevision: Int = 0) {
        self.source = source
        self.authRevision = authRevision
        _sort = State(initialValue: source.sorts[0].id)
        _rating = State(initialValue: source.ratings.first?.id ?? "")
    }
    private var key: String { "\(sort)|\(rating)|\(category)|\(query)|\(authRevision)" }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                Text(source.name).font(.largeTitle.bold())
                SearchField(text: $searchText) { query = searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
                HStack(spacing: 24) {
                    if !source.categories.isEmpty {
                        OptionPicker(title: "分类", selection: $category, options: source.categories)
                    }
                    OptionPicker(title: "排序", selection: $sort, options: source.sorts)
                    if !source.ratings.isEmpty {
                        OptionPicker(title: "分级", selection: $rating, options: source.ratings)
                    }
                }.disabled(!query.isEmpty && !source.supportsSearchFilters)
                if !query.isEmpty && !source.supportsSearchFilters { Text("搜索：\(query) · 使用站点搜索结果排序").foregroundStyle(.secondary) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 350), spacing: 40)], spacing: 44) {
                    ForEach(pager.items) { video in
                        NavigationLink { VideoDetail(source: source, id: video.id) } label: {
                            MediaCard(title: video.title, subtitle: video.author, url: video.thumbnail, portrait: video.isPortrait)
                        }.buttonStyle(.card).accessibilityIdentifier("video.card")
                    }
                }
                LoadFooter(loading: pager.loading, error: pager.error, empty: pager.items.isEmpty, hasNext: pager.next != nil) {
                    Task { await load() }
                }
            }.padding(60)
        }
        .task(id: key) { await load(reset: true) }
    }
    private func load(reset: Bool = false) async {
        let sort = sort, rating = rating, query = query, category = category
        await pager.load(reset: reset, key: key, first: 0) { try await source.videos(page: $0, sort: sort, rating: rating, query: query, category: category) }
    }
}

struct AlbumBrowser: View {
    let source: any AlbumSource
    @State private var pager = Pager<Album>()
    @State private var categories: [SourceOption] = []
    @State private var category = ""
    @State private var searchText = ""
    @State private var query = ""
    @State private var categoryError: String?
    private var key: String { "\(category)|\(query)" }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                Text(source.name).font(.largeTitle.bold())
                HStack(spacing: 24) {
                    SearchField(text: $searchText) { query = searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
                    OptionPicker(title: "分类", selection: $category, options: [SourceOption("", "最新 · 全部")] + categories)
                        .disabled(!query.isEmpty)
                }
                if let categoryError {
                    Text(categoryError).foregroundStyle(.orange)
                    Button("重新加载分类") { Task { await loadCategories() } }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 40)], spacing: 44) {
                    ForEach(pager.items) { album in
                        NavigationLink { AlbumDetail(source: source, id: album.id) } label: {
                            MediaCard(title: album.title, subtitle: "", url: album.cover, portrait: true, referer: source.imageReferer(albumID: nil))
                        }.buttonStyle(.card).accessibilityIdentifier("album.card")
                    }
                }
                LoadFooter(loading: pager.loading, error: pager.error, empty: pager.items.isEmpty, hasNext: pager.next != nil) { Task { await load() } }
            }.padding(60)
        }
        .task(id: key) { await load(reset: true) }
        .task { await loadCategories() }
    }
    private func loadCategories() async {
        do { if categories.isEmpty { categories = try await source.categories() }; categoryError = nil }
        catch { categoryError = error.localizedDescription }
    }
    private func load(reset: Bool = false) async {
        let category = category, query = query
        await pager.load(reset: reset, key: key, first: source.firstPage) { try await source.albums(page: $0, category: category, query: query) }
    }
}

struct SearchField: View {
    @Binding var text: String
    let submit: () -> Void
    var body: some View {
        HStack {
            TextField("搜索", text: $text).onSubmit(submit)
            Button(action: submit) { Image(systemName: "magnifyingglass") }.accessibilityLabel("搜索")
            if !text.isEmpty { Button("清除") { text = ""; submit() } }
        }
    }
}
struct LoadFooter: View {
    let loading: Bool
    let error: String?
    let empty: Bool
    let hasNext: Bool
    let load: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            if loading { ProgressView("加载中…") }
            else if let error { Text(error).foregroundStyle(.orange); Button("重试", action: load) }
            else if empty { ContentUnavailableView("没有结果", systemImage: "magnifyingglass", description: Text("尝试更换筛选或搜索词。")) }
            else if hasNext { Button("加载下一页", action: load) }
            else { Text("已到最后一页").foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity).padding(.vertical, 30)
    }
}
struct MediaCard: View {
    let title: String
    let subtitle: String
    let url: URL?
    let portrait: Bool
    var referer: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RemoteImage(url: url, referer: referer)
                .frame(height: portrait ? 330 : 205).clipped()
            Text(title).font(.headline).lineLimit(2).frame(height: 100, alignment: .topLeading)
            if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A scrollable native list keeps long tvOS option sets readable.
struct OptionPicker: View {
    let title: String
    @Binding var selection: String
    let options: [SourceOption]
    @State private var presented = false
    var body: some View {
        Button {
            presented = true
        } label: {
            HStack {
                Text("\(title)：\(options.first { $0.id == selection }?.title ?? "")")
                Image(systemName: "chevron.down")
            }
        }
        .accessibilityIdentifier("filter.\(title)")
        .sheet(isPresented: $presented) {
            NavigationStack {
                List(options) { option in
                    Button {
                        selection = option.id
                        presented = false
                    } label: {
                        HStack {
                            Text(option.title)
                            Spacer()
                            if option.id == selection { Image(systemName: "checkmark") }
                        }
                    }
                }.navigationTitle(title)
            }
        }
    }
}
