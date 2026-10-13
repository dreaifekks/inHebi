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

    public static func listURL(page: Int, sort: String, query: String, category: String) -> URL {
        var url = URLComponents(url: base.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        // The shared VideoSource uses zero-based pages; the site uses one-based pages.
        url.queryItems = [.init(name: "query", value: query), .init(name: "genre", value: category),
                          .init(name: "sort", value: sort), .init(name: "year", value: ""),
                          .init(name: "month", value: ""), .init(name: "page", value: String(page + 1))]
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
    public func video(id: String) async throws -> Video { try Self.parseVideo(await html(Self.watchURL(id: id)), id: id) }
    public func streams(for video: Video) async throws -> [VideoStream] {
        guard !video.availableStreams.isEmpty else { throw ShelfError.message("该播放页没有可用的 video source") }
        return video.availableStreams
    }

    public static func parseList(_ html: String, page: Int) throws -> Page<Video> {
        let doc = try SwiftSoup.parse(html)
        guard let wrapper = try doc.select("#home-rows-wrapper").first() else { throw ShelfError.parse("Hanime1 search results") }
        var seen = Set<String>()
        let videos: [Video] = try wrapper.select("a[href*=/watch?v=]").compactMap { link in
            guard let url = URL(string: try link.attr("href"), relativeTo: base),
                  let id = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems?.first(where: { $0.name == "v" })?.value,
                  let image = try link.select("img").first(), seen.insert(id).inserted else { return nil }
            let portrait = try !link.select(".home-rows-videos-title").isEmpty()
            let title = try link.select(".title, .home-rows-videos-title").text()
            let author = try link.parent()?.select(".subtitle a").first()?.text() ?? ""
            let duration = try link.select(".duration").text().split(separator: ":").compactMap { Double($0) }
            return Video(id: id, title: title, author: author,
                         duration: duration.isEmpty ? nil : duration.reduce(0) { $0 * 60 + $1 },
                         thumbnail: URL(string: try image.attr("src"), relativeTo: base)?.absoluteURL,
                         description: "", tags: [], fileURL: nil, isPortrait: portrait)
        }
        let next = try !doc.select("a[rel=next]").isEmpty()
        return Page(items: videos, nextPage: next ? page + 1 : nil)
    }
    public static func parseVideo(_ html: String, id: String) throws -> Video {
        let doc = try SwiftSoup.parse(html)
        let title = try doc.select("#shareBtn-title").text()
        guard !title.isEmpty else { throw ShelfError.parse("Hanime1 video title") }
        let author = try doc.select("#video-artist-name").text()
        let description = try doc.select(".video-caption-text").text()
        let duration = try doc.select("meta[property=og:video:duration]").attr("content")
        let poster = try doc.select("video#player").attr("poster")
        // Only actual tag/search links; exclude tag-vote actions and their count spans.
        let tags = try doc.select(".single-video-tag a[href^=/search]").map {
            $0.ownText().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return Video(id: id, title: title, author: author, duration: Double(duration),
                     thumbnail: poster.isEmpty ? nil : URL(string: poster, relativeTo: base)?.absoluteURL,
                     description: description, tags: tags, fileURL: nil,
                     availableStreams: try parseStreams(html))
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
