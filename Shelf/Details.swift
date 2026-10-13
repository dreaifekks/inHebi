import SwiftUI
import ShelfCore

struct VideoDetail: View {
    let source: any VideoSource
    let id: String
    @State private var video: Video?
    @State private var streams: [VideoStream] = []
    @State private var selected = ""
    @State private var playback: VideoStream?
    @State private var error: String?
    @State private var loading = true
    @State private var preparing = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if let video {
                    HStack(alignment: .top, spacing: 50) {
                        RemoteImage(url: video.thumbnail).frame(width: 620, height: 350)
                        VStack(alignment: .leading, spacing: 24) {
                            Text(video.title).font(.title.bold()).accessibilityIdentifier("video.title")
                            Text(video.author).foregroundStyle(.secondary)
                            if let duration = video.duration { Text("\(Int(duration) / 60):\(String(format: "%02d", Int(duration) % 60))").monospacedDigit() }
                            if !streams.isEmpty {
                                Picker("清晰度", selection: $selected) { ForEach(streams) { Text($0.name).tag($0.name) } }
                                Button { Task { await play() } } label: { Label(preparing ? "准备播放…" : "播放", systemImage: "play.fill") }.disabled(preparing).accessibilityIdentifier("video.play")
                            }
                        }
                    }
                    Text(video.tags.joined(separator: "  ·  ")).font(.callout).foregroundStyle(.cyan)
                    if !video.description.isEmpty { Text(video.description).font(.body).focusable() }
                }
                if loading { ProgressView("加载视频…") }
                if let error { Text(error).foregroundStyle(.orange); Button("重试") { Task { await load() } } }
            }.padding(70)
        }
        .task { await load() }
        .fullScreenCover(item: $playback) { PlayerScreen(stream: $0) }
    }
    private func load() async {
        loading = true; error = nil
        defer { loading = false }
        do {
            let detail = try await source.video(id: id)
            video = detail
            streams = try await source.streams(for: detail)
            guard let best = streams.first else { throw ShelfError.message("暂时没有可播放的清晰度") }
            selected = best.name
        } catch { self.error = error.localizedDescription }
    }
    private func play() async {
        preparing = true; error = nil
        defer { preparing = false }
        do {
            // Signed URLs expire: refresh at play time after a detail screen has been open.
            let detail = try await source.video(id: id)
            streams = try await source.streams(for: detail)
            guard let stream = streams.first(where: { $0.name == selected }) ?? streams.first else { throw ShelfError.message("暂时没有可播放的清晰度") }
            playback = stream
        } catch { self.error = error.localizedDescription }
    }
}

struct AlbumDetail: View {
    let source: any AlbumSource
    let id: String
    @State private var album: Album?
    @State private var pages: [URL] = []
    @State private var error: String?
    @State private var loading = true
    @State private var reading = false
    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 70) {
                if let album {
                    RemoteImage(url: album.cover, referer: WnacgSource.base.absoluteString).frame(width: 460, height: 630)
                    VStack(alignment: .leading, spacing: 36) {
                        Text(album.title).font(.title.bold()).accessibilityIdentifier("album.title")
                        if let count = album.pageCount { Text("\(count) 页").foregroundStyle(.secondary) }
                        Button("开始阅读") { Task { await openReader() } }.disabled(loading).accessibilityIdentifier("album.read")
                        Text("左右翻页 · 向左为下一页\n按选择键显示阅读选项").foregroundStyle(.secondary)
                        status
                    }
                } else { status }
            }.padding(70)
        }
        .task { await load() }
        .fullScreenCover(isPresented: $reading) { ReaderView(pages: pages, albumID: id) }
    }
    @ViewBuilder private var status: some View {
        if loading { ProgressView("加载中…") }
        if let error { Text(error).foregroundStyle(.orange); Button("重试") { Task { await load() } } }
    }
    private func load() async {
        loading = true; error = nil
        defer { loading = false }
        do { album = try await source.album(id: id) }
        catch { self.error = error.localizedDescription }
    }
    private func openReader() async {
        loading = true; error = nil
        defer { loading = false }
        do { pages = try await source.pages(id: id); reading = true }
        catch { self.error = error.localizedDescription }
    }
}
