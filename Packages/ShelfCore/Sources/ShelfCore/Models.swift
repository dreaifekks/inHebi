import Foundation

public struct Page<Item: Sendable>: Sendable {
    public let items: [Item]
    public let nextPage: Int?
    public init(items: [Item], nextPage: Int?) { self.items = items; self.nextPage = nextPage }
}
public struct SourceOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public init(_ id: String, _ title: String) { self.id = id; self.title = title }
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
}
public protocol VideoSource: Sendable {
    var name: String { get }
    var sorts: [SourceOption] { get }
    var ratings: [SourceOption] { get }
    func videos(page: Int, sort: String, rating: String, query: String) async throws -> Page<Video>
    func video(id: String) async throws -> Video
    func streams(for video: Video) async throws -> [VideoStream]
}
public protocol AlbumSource: Sendable {
    var name: String { get }
    func categories() async throws -> [SourceOption]
    func albums(page: Int, category: String, query: String) async throws -> Page<Album>
    func album(id: String) async throws -> Album
    func pages(id: String) async throws -> [URL]
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

/// Page indices in visual left-to-right order. Reading progresses right-to-left.
public enum ReaderLayout {
    public static func visibleIndices(page: Int, count: Int, spread: Bool) -> [Int] {
        guard count > 0 else { return [] }
        let start = min(max(0, page), count - 1)
        return spread && start + 1 < count ? [start + 1, start] : [start]
    }
    public static func advanced(page: Int, count: Int, spread: Bool, forward: Bool) -> Int {
        let step = spread ? 2 : 1
        if forward && page + step >= count { return page }
        return min(max(0, page + (forward ? step : -step)), max(0, count - 1))
    }
}
