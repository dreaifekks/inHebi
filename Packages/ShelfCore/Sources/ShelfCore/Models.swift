import Foundation

public struct Page<Item: Sendable>: Sendable {
    public let items: [Item]
    public let nextPage: Int?
    public init(items: [Item], nextPage: Int?) { self.items = items; self.nextPage = nextPage }
}
public struct SourceOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public var children: [SourceOption]
    public var flattened: [SourceOption] {
        [SourceOption(id, title)] + children.map { SourceOption($0.id, title + "·" + $0.title) }
    }
    public init(_ id: String, _ title: String, children: [SourceOption] = []) { self.id = id; self.title = title; self.children = children }
}
public struct Video: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let author: String
    public let duration: Double?
    public let thumbnail: URL?
    public let description: String
    public let tags: [String]
    public let fileURL: URL?
    public var availableStreams: [VideoStream] = []
    public var isPortrait = false
    public var width: Int?
    public var height: Int?
    public var createdAt: String?
    public var numViews: Int?
    public var numLikes: Int?
    public var numComments: Int?
    public var rating: String?
    public var authorID: String?
    public var embedURL: URL?
    public var viewsText: String?
    public var feedbackText: String?
    public var categoryText: String?
    public var tagLinks: [BrowseTag] = []
    public var authorVideos: [Video] = []
    public var relatedVideos: [Video] = []
    public var authorSectionTitle = "作者的其他视频"
}
public struct VideoStream: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let url: URL
}
public struct Album: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let cover: URL?
    public let pageCount: Int?
    public var categoryText: String?
    public var createdAt: String?
    public var tags: [BrowseTag] = []
    public var previews: [URL] = []
}
public struct BrowseTag: Identifiable, Hashable, Sendable {
    public var id: String { "\(usesSearch):\(value)" }
    public let title: String
    public let value: String
    public var usesSearch = false
}
public enum VideoFilter: Hashable, Sendable {
    case author(String), tag(String), query(String)
}
public protocol VideoSource: Sendable {
    var name: String { get }
    var sorts: [SourceOption] { get }
    var ratings: [SourceOption] { get }
    var categories: [SourceOption] { get }
    var supportsSearchFilters: Bool { get }
    func videos(page: Int, sort: String, rating: String, query: String, category: String) async throws -> Page<Video>
    func video(id: String) async throws -> Video
    func streams(for video: Video) async throws -> [VideoStream]
    func filteredVideos(_ filter: VideoFilter, page: Int) async throws -> Page<Video>
    func creatorVideos(for video: Video) async throws -> [Video]
    func relatedVideos(for video: Video) async throws -> [Video]
}
public extension VideoSource {
    var categories: [SourceOption] { [] }
    var supportsSearchFilters: Bool { false }
    func creatorVideos(for video: Video) async throws -> [Video] { video.authorVideos }
    func relatedVideos(for video: Video) async throws -> [Video] { video.relatedVideos }
}
public protocol AlbumSource: Sendable {
    var name: String { get }
    var firstPage: Int { get }
    func imageReferer(albumID: String?) -> String
    func categories() async throws -> [SourceOption]
    func albums(page: Int, category: String, query: String, tag: String) async throws -> Page<Album>
    func album(id: String) async throws -> Album
    func pages(id: String) async throws -> [URL]
}
public extension AlbumSource {
    func albums(page: Int, category: String, query: String) async throws -> Page<Album> {
        try await albums(page: page, category: category, query: query, tag: "")
    }
}
public enum ShelfError: LocalizedError, Sendable {
    case http(Int), parse(String), message(String)
    public var errorDescription: String? {
        switch self {
        case .http(let code): "服务器返回 HTTP \(code)"
        case .parse(let field): "无法解析 \(field)，站点格式可能已变化"
        case .message(let text): text
        }
    }
}

/// Zero-based page indices. A spread always starts at the selected page, regardless of parity.
public enum ReaderLayout {
    public static func visibleIndices(page: Int, count: Int, spread: Bool, rightToLeft: Bool = true) -> [Int] {
        guard count > 0 else { return [] }
        let start = min(max(0, page), count - 1)
        guard spread && start + 1 < count else { return [start] }
        return rightToLeft ? [start + 1, start] : [start, start + 1]
    }
    public static func advanced(page: Int, count: Int, spread: Bool, forward: Bool) -> Int {
        let step = spread ? 2 : 1
        if forward && page + step >= count { return page }
        return min(max(0, page + (forward ? step : -step)), max(0, count - 1))
    }
    public static func prefetchIndices(page: Int, count: Int, spread: Bool) -> Range<Int> {
        let start = min(count, page + (spread ? 2 : 1))
        return start..<min(count, page + 6)
    }
}
