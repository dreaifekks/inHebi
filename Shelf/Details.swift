import ShelfCore
import SwiftUI

struct VideoDetail: View {
  let source: any VideoSource
  let id: String
  @State private var video: Video?
  @State private var streams: [VideoStream] = []
  @State private var selected = ""
  @State private var playback: VideoPlayback?
  @State private var error: String?
  @State private var relatedError: String?
  @State private var loading = true
  @State private var preparing = false
  @State private var expanded = false
  @State private var creators: [Video] = []
  @State private var related: [Video] = []
  @FocusState private var focus: Focus?
  private enum Focus: Hashable {
    case play
    case tag(String)
  }
  var body: some View {
    Group {
      if let video {
        VStack(alignment: .leading, spacing: 28) {
          HStack(alignment: .top, spacing: 48) {
            RemoteImage(url: video.thumbnail, maxPixelSize: ShelfLayout.detailPixels)
              .frame(width: 640, height: 360).clipShape(RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 18) {
              Text(video.title).font(ShelfLayout.detailFont).lineLimit(3).minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("video.title")
              HStack(spacing: 18) {
                NavigationLink {
                  VideoBrowser(
                    source: source, filter: .author(video.authorID ?? video.author),
                    title: video.author)
                } label: {
                  Text(video.author)
                }
                .font(.system(size: 29)).accessibilityIdentifier("video.author")
                Text(
                  MediaText.joined([
                    MediaText.date(video.createdAt), MediaText.duration(video.duration),
                    resolution(video),
                  ])
                )
                .font(.system(size: 29)).lineLimit(1)
              }
              Text(statistics(video)).font(.system(size: 29)).foregroundStyle(.secondary).lineLimit(
                2)
              HStack(spacing: 24) {
                if video.embedURL != nil {
                  Text("外站嵌入视频，无法在 Shelf 播放").font(.system(size: 29)).foregroundStyle(.secondary)
                } else {
                  Button {
                    Task { await play() }
                  } label: {
                    Label(preparing ? "准备播放…" : "播放", systemImage: "play.fill")
                  }
                  .font(.system(size: 29)).focused($focus, equals: .play)
                  .accessibilityIdentifier("video.play")
                  Picker("清晰度", selection: $selected) {
                    ForEach(streams) { Text($0.name).tag($0.name) }
                  }
                  .font(.system(size: 25)).frame(maxWidth: .infinity)
                }
              }
              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                  ForEach(video.tagLinks) { tag in
                    NavigationLink {
                      VideoBrowser(
                        source: source,
                        filter: tag.usesSearch ? .query(tag.value) : .tag(tag.value),
                        title: tag.title)
                    } label: {
                      Text(tag.title)
                    }
                    .font(.system(size: 29)).focused($focus, equals: .tag(tag.id))
                  }
                }.padding(10)
              }.focusSection().frame(height: 70)
            }
          }
          ScrollView {
            VStack(alignment: .leading, spacing: 28) {
              if !video.description.isEmpty {
                Button {
                  expanded.toggle()
                } label: {
                  VStack(alignment: .leading, spacing: 8) {
                    Text(video.description).font(.system(size: 29)).lineLimit(expanded ? nil : 4)
                      .multilineTextAlignment(.leading).frame(
                        maxWidth: .infinity, alignment: .leading)
                    Text(expanded ? "收起简介" : "展开简介").font(.system(size: 25)).foregroundStyle(
                      .secondary)
                  }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.bordered).accessibilityIdentifier("video.description")
              }
              if !creators.isEmpty {
                VideoRail(title: video.authorSectionTitle, videos: creators, source: source)
              }
              if !related.isEmpty { VideoRail(title: "相关视频", videos: related, source: source) }
              if let relatedError { Text(relatedError).foregroundStyle(.orange) }
            }.padding(.vertical, 18)
          }
          if let error {
            Text(error).foregroundStyle(.orange)
            Button("重试") { Task { await load() } }
          }
        }
      } else if let error {
        VStack(spacing: 24) {
          Text(error).foregroundStyle(.orange)
          Button("重试") { Task { await load() } }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ProgressView("加载视频…").frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .padding(.horizontal, ShelfLayout.horizontalInset).padding(.top, 40).padding(.bottom, 20)
    .ignoresSafeArea(.container, edges: .horizontal)
    .defaultFocus($focus, .play)
    .task { if video == nil { await load() } }
    .onChange(of: loading) { _, value in
      if !value {
        focus = video?.embedURL == nil ? .play : video?.tagLinks.first.map { .tag($0.id) }
      }
    }
    .fullScreenCover(item: $playback, onDismiss: { focus = .play }) { PlayerScreen(playback: $0) }
  }
  private func resolution(_ video: Video) -> String? {
    if let width = video.width, let height = video.height { return "\(width)×\(height)" }
    return streams.first?.name
  }
  private func statistics(_ video: Video) -> String {
    MediaText.joined([
      video.viewsText ?? MediaText.count(video.numViews).map { "\($0)次播放" },
      MediaText.count(video.numLikes).map { "\($0)喜欢" } ?? video.feedbackText.map { "好评 \($0)" },
      MediaText.count(video.numComments).map { "\($0)评论" },
      video.categoryText ?? video.rating.map { $0 == "general" ? "一般" : "成人" },
    ])
  }
  private func load() async {
    loading = true
    error = nil
    do {
      let detail = try await source.video(id: id)
      video = detail
      if detail.embedURL == nil {
        streams = try await source.streams(for: detail)
        selected = streams.first?.name ?? ""
      }
      loading = false
      do {
        async let authorItems = source.creatorVideos(for: detail)
        async let relatedItems = source.relatedVideos(for: detail)
        (creators, related) = try await (authorItems, relatedItems)
      } catch is CancellationError {} catch let error as URLError where error.code == .cancelled {
      } catch { relatedError = error.localizedDescription }
    } catch is CancellationError { loading = false } catch let error as URLError
      where error.code == .cancelled
    { loading = false } catch {
      self.error = error.localizedDescription
      loading = false
    }
  }
  private func play() async {
    guard !preparing else { return }
    preparing = true
    error = nil
    defer { preparing = false }
    do {
      let detail = try await source.video(id: id)
      streams = try await source.streams(for: detail)
      guard let stream = streams.first(where: { $0.name == selected }) ?? streams.first else {
        throw ShelfError.message("没有可播放的清晰度")
      }
      playback = VideoPlayback(video: detail, stream: stream)
    } catch { self.error = error.localizedDescription }
  }
}

struct VideoRail: View {
  let title: String
  let videos: [Video]
  let source: any VideoSource
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(title).font(.system(size: 32, weight: .bold))
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 36) {
          ForEach(videos) { video in
            VStack(alignment: .leading, spacing: 12) {
              NavigationLink {
                VideoDetail(source: source, id: video.id)
              } label: {
                RemoteImage(url: video.thumbnail, maxPixelSize: ShelfLayout.cardPixels, fill: true)
                  .frame(width: 400, height: 225).clipShape(RoundedRectangle(cornerRadius: 16))
              }.buttonStyle(.card).accessibilityLabel(video.title)
              Text(video.title).font(.system(size: 29)).lineLimit(2).frame(
                width: 400, height: 72, alignment: .topLeading)
            }
          }
        }.padding(.horizontal, 20).padding(.vertical, 20)
      }.focusSection()
    }
  }
}

struct AlbumDetail: View {
  let source: any AlbumSource
  let id: String
  @State private var album: Album?
  @State private var reading: ReadingSession?
  @State private var error: String?
  @State private var opening = false
  @State private var lastPage = 0
  @FocusState private var readFocused: Bool
  var body: some View {
    Group {
      if let album {
        ScrollView {
          VStack(alignment: .leading, spacing: 30) {
            HStack(alignment: .top, spacing: 48) {
              RemoteImage(
                url: album.cover, referer: source.imageReferer(albumID: id),
                maxPixelSize: ShelfLayout.detailPixels
              ).frame(width: 480, height: 640)
              VStack(alignment: .leading, spacing: 28) {
                Text(album.title).font(ShelfLayout.detailFont).lineLimit(3).minimumScaleFactor(0.8)
                  .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier(
                    "album.title")
                Text(
                  MediaText.joined([
                    album.categoryText, album.pageCount.map { "\($0) 页" }, album.createdAt,
                  ])
                ).font(.system(size: 29)).foregroundStyle(.secondary)
                HStack(spacing: 24) {
                  Button {
                    Task { await openReader(at: lastPage) }
                  } label: {
                    Label(
                      opening ? "正在打开…" : (lastPage > 0 ? "从第 \(lastPage + 1) 页继续" : "开始阅读"),
                      systemImage: "book")
                  }
                  .focused($readFocused).accessibilityIdentifier("album.read")
                  if lastPage > 0 { Button("从头阅读") { Task { await openReader(at: 0) } } }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 16) {
                    ForEach(album.tags) { tag in
                      NavigationLink(tag.title) { AlbumBrowser(source: source, tag: tag.value) }
                        .font(.system(size: 29))
                    }
                  }.padding(10)
                }.frame(height: 80).focusSection()
                if let error { Text(error).foregroundStyle(.orange) }
              }
            }
            if !album.previews.isEmpty {
              Text("前 \(album.previews.count) 页预览").font(.system(size: 32, weight: .bold))
              ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 30) {
                  ForEach(Array(album.previews.enumerated()), id: \.offset) { index, url in
                    VStack(spacing: 10) {
                      Button {
                        Task { await openReader(at: index) }
                      } label: {
                        RemoteImage(
                          url: url, referer: source.imageReferer(albumID: id),
                          maxPixelSize: ShelfLayout.cardPixels
                        ).frame(width: 220, height: 293)
                      }.buttonStyle(.card).accessibilityLabel("第 \(index + 1) 页")
                      Text("第 \(index + 1) 页").font(.system(size: 25))
                    }
                  }
                }.padding(20)
              }.focusSection()
            }
          }.padding(.top, 40).padding(.bottom, 20)
        }
      } else if let error {
        VStack {
          Text(error).foregroundStyle(.orange)
          Button("重试") { Task { await load() } }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ProgressView("加载相册…").frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .padding(.horizontal, ShelfLayout.horizontalInset).ignoresSafeArea(
      .container, edges: .horizontal
    )
    .defaultFocus($readFocused, true)
    .task {
      lastPage = ReaderHistory.lastPage(id)
      if album == nil { await load() }
    }
    .navigationDestination(item: $reading) { ReaderView(session: $0) }
    .onChange(of: reading) { _, value in
      if value == nil {
        lastPage = ReaderHistory.lastPage(id)
        readFocused = true
      }
    }
  }
  private func load() async {
    error = nil
    do {
      album = try await source.album(id: id)
      await Task.yield()
      readFocused = true
    } catch is CancellationError {} catch let error as URLError where error.code == .cancelled {
    } catch { self.error = error.localizedDescription }
  }
  private func openReader(at page: Int) async {
    guard !opening else { return }
    opening = true
    error = nil
    defer { opening = false }
    do {
      reading = ReadingSession(
        pages: try await source.pages(id: id), albumID: id,
        referer: source.imageReferer(albumID: id), startPage: page)
    } catch { self.error = error.localizedDescription }
  }
}
