import Foundation
import SwiftSoup

public struct Hanime1Source: VideoSource {
    /// Canonical domain; the old hanime1.me domain returns a Cloudflare challenge.
    public static let base = URL(string: "https://hanimeone.me")!
    public let name = "Hanime1"
    public let ratings: [SourceOption] = []
    public let supportsSearchFilters = true
    // Values are the search form's data-value attributes, not the translated labels.
    public let categories = [SourceOption("", "全部")] + ["裏番", "泡麵番", "Motion Anime", "3DCG", "2.5D", "2D動畫", "AI生成", "MMD", "Cosplay", "新番預告"].map { SourceOption($0, $0) }
    public let sorts = ["最新上市", "最新上傳", "本日排行", "本週排行", "本月排行", "觀看次數", "讚好比例", "時長最長", "他們在看"].map { SourceOption($0, $0) }
    private let http: HTTPClient
    public init(http: HTTPClient = HTTPClient()) { self.http = http }

    public static func listURL(page: Int, sort: String, query: String, category: String, tag: String = "") -> URL {
        var url = URLComponents(url: base.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        // The shared VideoSource uses zero-based pages; the site uses one-based pages.
        url.queryItems = [.init(name: "query", value: query), .init(name: "genre", value: category),
                          .init(name: "sort", value: sort), .init(name: "year", value: ""),
                          .init(name: "month", value: ""), .init(name: "page", value: String(page + 1))]
        if !tag.isEmpty { url.queryItems?.append(.init(name: "tags[]", value: tag)) }
        return url.url!
    }
    public static func watchURL(id: String) -> URL {
        var url = URLComponents(url: base.appendingPathComponent("watch"), resolvingAgainstBaseURL: false)!
        url.queryItems = [.init(name: "v", value: id)]
        return url.url!
    }
    private func html(_ url: URL) async throws -> String { String(decoding: try await http.data(url), as: UTF8.self) }
    public func videos(page: Int = 0, sort: String = "最新上市", rating: String = "", query: String = "", category: String = "") async throws -> Page<Video> {
        try Self.parseList(await html(Self.listURL(page: page, sort: sort, query: query, category: category)), page: page)
    }
    public func filteredVideos(_ filter: VideoFilter, page: Int) async throws -> Page<Video> {
        switch filter {
        case .author(let name), .query(let name): return try await videos(page: page, query: name)
        case .tag(let tag): return try Self.parseList(await html(Self.listURL(page: page, sort: sorts[0].id, query: "", category: "", tag: tag)), page: page)
        }
    }
    public func video(id: String) async throws -> Video { try Self.parseVideo(await html(Self.watchURL(id: id)), id: id) }
    public func streams(for video: Video) async throws -> [VideoStream] {
        guard !video.availableStreams.isEmpty else { throw ShelfError.message("该播放页没有可用的 video source") }
        return video.availableStreams
    }

    public static func parseList(_ html: String, page: Int) throws -> Page<Video> {
        let doc = try SwiftSoup.parse(html)
        guard let wrapper = try doc.select("#home-rows-wrapper").first() else { throw ShelfError.parse("Hanime1 search results") }
        let videos = try parseCards(wrapper)
        let next = try !doc.select("a[rel=next]").isEmpty()
        return Page(items: videos, nextPage: next ? page + 1 : nil)
    }
    private static func parseCards(_ root: Element) throws -> [Video] {
        var seen = Set<String>()
        return try root.select(".video-item-container, a:has(.home-rows-videos-title)").compactMap { card in
            let link = try card.tagName() == "a" ? card : card.select("a[href*=/watch?v=]").first()
            guard let link, let url = URL(string: try link.attr("href"), relativeTo: base),
                  let id = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems?.first(where: { $0.name == "v" })?.value,
                  let image = try card.select("img").first(), seen.insert(id).inserted else { return nil }
            let portrait = try !card.select(".home-rows-videos-title").isEmpty()
            let title = try card.select(".title, .video-title, .home-rows-videos-title").text()
            let author = try card.select(".subtitle a, .meta-author a").first()?.text() ?? ""
            let duration = try card.select(".duration").text().split(separator: ":").compactMap { Double($0) }
            var video = Video(id: id, title: title, author: author,
                             duration: duration.isEmpty ? nil : duration.reduce(0) { $0 * 60 + $1 },
                             thumbnail: URL(string: try image.attr("src"), relativeTo: base)?.absoluteURL,
                             description: "", tags: [], fileURL: nil, isPortrait: portrait)
            video.createdAt = try card.select(".subtitle-time, .meta-stats span").text().trimmingCharacters(in: CharacterSet(charactersIn: " •"))
            let stats = try card.select(".stat-item").map { try $0.text() }
            video.viewsText = stats.first { $0.contains("次") }
            video.feedbackText = stats.first { $0.contains("%") }?.replacingOccurrences(of: "thumb_up", with: "").trimmingCharacters(in: .whitespaces)
            return video
        }
    }
    public static func parseVideo(_ html: String, id: String) throws -> Video {
        let doc = try SwiftSoup.parse(html)
        let title = try doc.select("#shareBtn-title").text()
        guard !title.isEmpty else { throw ShelfError.parse("Hanime1 video title") }
        let author = try doc.select("#video-artist-name").text()
        let description = try doc.select(".video-caption-text").text()
        let duration = try doc.select("meta[property=og:video:duration]").attr("content")
        let poster = try doc.select("video#player").attr("poster")
        let tagLinks = try doc.select(".single-video-tag a[href^=/search]").compactMap { link -> BrowseTag? in
            let params = URLComponents(string: try link.attr("href"))?.queryItems ?? []
            guard let item = params.first(where: { $0.name == "tags[]" || $0.name == "query" }), let value = item.value else { return nil }
            return BrowseTag(title: link.ownText().trimmingCharacters(in: .whitespacesAndNewlines), value: value, usesSearch: item.name == "query")
        }
        var video = Video(id: id, title: title, author: author, duration: Double(duration),
                          thumbnail: poster.isEmpty ? nil : URL(string: poster, relativeTo: base)?.absoluteURL,
                          description: description, tags: tagLinks.map(\.title), fileURL: nil,
                          availableStreams: try parseStreams(html))
        video.tagLinks = tagLinks
        video.authorID = author
        video.categoryText = try doc.select("#video-artist-name").first()?.parent()?.select("a[href*=genre=]").text()
        let info = try doc.select(".video-description-panel .hidden-xs").text()
        if let range = info.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) {
            video.createdAt = String(info[range])
            video.viewsText = info[..<range.lowerBound].replacingOccurrences(of: "观看次数：", with: "").replacingOccurrences(of: "觀看次數：", with: "").trimmingCharacters(in: .whitespaces)
        }
        video.feedbackText = try doc.select("#video-like-btn").text().replacingOccurrences(of: "thumb_up", with: "").trimmingCharacters(in: .whitespaces)
        if let playlist = try doc.select("#playlist-scroll").first() {
            video.authorVideos = try parseCards(playlist).filter { $0.id != id }
            video.authorSectionTitle = try doc.select("#playlist-top-block h4").first()?.text() ?? "作者的其他视频"
        }
        if let related = try doc.select("#related-tabcontent").first() {
            video.relatedVideos = Array(try parseCards(related).filter { $0.id != id }.prefix(12))
        }
        return video
    }
    public static func parseStreams(_ html: String) throws -> [VideoStream] {
        let doc = try SwiftSoup.parse(html)
        let sources = try doc.select("video#player source[src]").map { source -> (Int, VideoStream) in
            let raw = try source.attr("src")
            guard let url = URL(string: raw, relativeTo: base)?.absoluteURL else { throw ShelfError.parse("Hanime1 source URL") }
            let size = Int(try source.attr("size")) ?? 0
            let name = size > 0 ? "\(size)p" : "自动"
            return (size, VideoStream(name: name, url: url))
        }
        guard !sources.isEmpty else { throw ShelfError.message("该播放页没有可用的 video source") }
        return sources.sorted { $0.0 > $1.0 }.map(\.1)
    }
}
