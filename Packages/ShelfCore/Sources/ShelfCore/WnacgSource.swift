import Foundation
import SwiftSoup

public struct WnacgSource: AlbumSource {
    public let name = "wnacg"
    public static let base = URL(string: "https://www.wnacg.com/")!
    private let http: HTTPClient
    public init(http: HTTPClient = HTTPClient()) { self.http = http }
    private func html(_ url: URL) async throws -> String {
        String(decoding: try await http.data(url), as: UTF8.self)
    }
    public func categories() async throws -> [SourceOption] { try Self.parseCategories(await html(Self.base)) }
    public static func listURL(page: Int, category: String, query: String) -> URL {
        if !query.isEmpty {
            var url = URLComponents(url: base.appendingPathComponent("search/"), resolvingAgainstBaseURL: false)!
            url.queryItems = [.init(name: "q", value: query), .init(name: "f", value: "_all"), .init(name: "s", value: "create_time_DESC"), .init(name: "syn", value: "yes"), .init(name: "p", value: String(page))]
            return url.url!
        }
        return base.appendingPathComponent("albums-index-page-\(page)\(category.isEmpty ? "" : "-cate-" + category).html")
    }
    public func albums(page: Int = 1, category: String = "", query: String = "") async throws -> Page<Album> {
        try Self.parseList(await html(Self.listURL(page: page, category: category, query: query)), page: page)
    }
    public func album(id: String) async throws -> Album {
        try Self.parseAlbum(await html(Self.base.appendingPathComponent("photos-index-aid-\(id).html")), id: id)
    }
    public func pages(id: String) async throws -> [URL] {
        try Self.parsePages(await html(Self.base.appendingPathComponent("photos-gallery-aid-\(id).html")))
    }
    public static func imageURL(_ value: String) -> URL? {
        if value.hasPrefix("//") { return URL(string: "https://" + value.drop(while: { $0 == "/" })) }
        return URL(string: value, relativeTo: base)?.absoluteURL
    }
    public static func parseCategories(_ html: String) throws -> [SourceOption] {
        let doc = try SwiftSoup.parse(html)
        var seen = Set<String>()
        return try doc.select("a[href^=/albums-index-cate-]").compactMap {
            let href = try $0.attr("href")
            guard let id = capture(#"cate-(\d+)"#, in: href), seen.insert(id).inserted else { return nil }
            return SourceOption(id, try $0.text())
        }
    }
    public static func parseList(_ html: String, page: Int) throws -> Page<Album> {
        let doc = try SwiftSoup.parse(html)
        let items: [Album] = try doc.select(".gallary_item").map {
            let link = try $0.select("a[href*=photos-index-aid-]").first()
            guard let link, let id = capture(#"aid-(\d+)"#, in: try link.attr("href")) else { throw ShelfError.parse("album id") }
            let title = try $0.select(".title").text()
            let src = try $0.select("img").first()?.attr("src")
            return Album(id: id, title: title, cover: src.flatMap(imageURL), pageCount: nil)
        }
        guard try !items.isEmpty || doc.select("#bodywrap").first() != nil else { throw ShelfError.parse("wnacg list") }
        let next = try doc.select(".paginator a").contains { link in
            let href = try link.attr("href")
            let index = capture(#"(?:page-|[?&]p=)(\d+)"#, in: href).flatMap(Int.init)
            return (index ?? 0) > page
        }
        return Page(items: items, nextPage: next ? page + 1 : nil)
    }
    public static func parseAlbum(_ html: String, id: String) throws -> Album {
        let doc = try SwiftSoup.parse(html)
        let title = try doc.select("#bodywrap h2").text()
        guard !title.isEmpty else { throw ShelfError.parse("album title") }
        let labels = try doc.select(".uwconn label").text()
        let count = capture(#"頁數[：:]\s*(\d+)"#, in: labels).flatMap(Int.init)
        let cover = try doc.select(".uwthumb img").first()?.attr("src")
        return Album(id: id, title: title, cover: cover.flatMap(imageURL), pageCount: count)
    }
    public static func parsePages(_ html: String) throws -> [URL] {
        // gallery is document.writeln("...JS..."); decode only its string literals, never execute JS.
        let writes = try NSRegularExpression(pattern: #"document\.writeln\(("(?:\\.|[^"\\])*")\);"#)
        let text = try writes.matches(in: html, range: NSRange(html.startIndex..., in: html)).map { match in
            try JSONDecoder().decode(String.self, from: Data(html[Range(match.range(at: 1), in: html)!].replacingOccurrences(of: "\t", with: "\\t").utf8))
        }.joined(separator: "\n")
        guard let list = capture(#"(?s)var imglist\s*=\s*\[(.*?)\];"#, in: text) else { throw ShelfError.parse("imglist") }
        let expression = try NSRegularExpression(pattern: #"url:\s*fast_img_host\s*\+\s*"([^"]+)""#)
        let pages = expression.matches(in: list, range: NSRange(list.startIndex..., in: list)).compactMap { match -> URL? in
            let raw = String(list[Range(match.range(at: 1), in: list)!])
            guard !raw.hasPrefix("/themes/") else { return nil }
            return imageURL(raw)
        }
        guard !pages.isEmpty else { throw ShelfError.parse("gallery image URLs") }
        return pages
    }
    private static func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
}
