import Foundation
import CryptoKit

public actor IwaraSource: VideoSource {
    public nonisolated let name = "iwara"
    public nonisolated let sorts = [SourceOption("date", "最新"), SourceOption("trending", "趋势"), SourceOption("popularity", "热门"), SourceOption("views", "播放"), SourceOption("likes", "喜欢")]
    public nonisolated let ratings = [SourceOption("all", "全部"), SourceOption("general", "一般"), SourceOption("ecchi", "成人")]
    // Verified against yt-dlp/extractor/iwara.py on 2026-10-14.
    public static let versionSalt = "mSvL05GfEmeEmsEYfGCnVpEjYgTJraJN"
    private let http: HTTPClient
    private var userToken: String?
    private var accessToken: String?
    private var accessExpiry = Date.distantPast
    private var authGeneration = 0
    public init(http: HTTPClient = HTTPClient()) { self.http = http }
    public func setUserToken(_ token: String?) {
        authGeneration += 1
        userToken = token; accessToken = nil; accessExpiry = .distantPast
    }
    public func login(email: String, password: String) async throws -> String {
        var request = HTTPClient.request(Self.url("user/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Login(email: email, password: password))
        let reply = try JSONDecoder().decode(UserToken.self, from: await http.data(for: request))
        setUserToken(reply.token)
        do { _ = try await bearer() } catch { setUserToken(nil); throw error }
        return reply.token
    }
    private func bearer() async throws -> String? {
        guard let userToken else { return nil }
        if let accessToken, accessExpiry > Date() { return accessToken }
        let generation = authGeneration
        var request = HTTPClient.request(Self.url("user/token"), headers: ["Authorization": "Bearer \(userToken)", "Content-Type": "application/json"])
        request.httpMethod = "POST"; request.httpBody = Data()
        let reply = try JSONDecoder().decode(AccessToken.self, from: await http.data(for: request))
        guard generation == authGeneration else { throw CancellationError() }
        accessToken = reply.accessToken
        accessExpiry = Date().addingTimeInterval(50 * 60)
        return reply.accessToken
    }
    private func api(_ path: String, query: [URLQueryItem] = []) async throws -> Data {
        let token = try await bearer()
        let request = HTTPClient.request(Self.url(path, query: query), headers: token.map { ["Authorization": "Bearer \($0)"] } ?? [:])
        do { return try await http.data(for: request) }
        catch ShelfError.http(401) where token != nil {
            accessToken = nil
            let refreshed = try await bearer()
            return try await http.data(Self.url(path, query: query), headers: refreshed.map { ["Authorization": "Bearer \($0)"] } ?? [:])
        }
    }
    public nonisolated static func url(_ path: String, query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(string: "https://api.iwara.tv/\(path)")!
        if !query.isEmpty { components.queryItems = query }
        return components.url!
    }
    public func videos(page: Int = 0, sort: String = "date", rating: String = "all", query: String = "") async throws -> Page<Video> {
        var params = [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "limit", value: "24"), URLQueryItem(name: "sort", value: sort), URLQueryItem(name: "rating", value: rating)]
        if !query.isEmpty { params = [.init(name: "type", value: "videos"), .init(name: "query", value: query), .init(name: "page", value: String(page))] }
        return try Self.parseList(await api(query.isEmpty ? "videos" : "search", query: params))
    }
    public func video(id: String) async throws -> Video { try Self.parseVideo(await api("video/\(id)")) }
    public func streams(for video: Video) async throws -> [VideoStream] {
        guard let url = video.fileURL else { throw ShelfError.message("该视频没有可播放文件（可能为外站嵌入视频）") }
        return try Self.parseStreams(await http.data(url, headers: ["X-Version": Self.version(for: url)]))
    }
    public nonisolated static func version(for url: URL) throws -> String {
        guard let expires = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "expires" })?.value else { throw ShelfError.parse("fileUrl.expires") }
        return Insecure.SHA1.hash(data: Data("\(url.lastPathComponent)_\(expires)_\(versionSalt)".utf8)).map { String(format: "%02x", $0) }.joined()
    }
    public nonisolated static func parseList(_ data: Data) throws -> Page<Video> {
        let result = try JSONDecoder().decode(List.self, from: data)
        // List count may be offset + limit + 1, a pagination lower bound rather than total.
        return Page(items: result.results.map(\.video), nextPage: (result.page + 1) * result.limit < result.count ? result.page + 1 : nil)
    }
    public nonisolated static func parseVideo(_ data: Data) throws -> Video { try JSONDecoder().decode(Item.self, from: data).video }
    public nonisolated static func parseStreams(_ data: Data) throws -> [VideoStream] {
        let streams = try JSONDecoder().decode([Stream].self, from: data)
        return try streams.sorted { quality($0.name) > quality($1.name) }.map {
            let raw = $0.src.view ?? $0.src.download
            guard let raw, let url = URL(string: raw.hasPrefix("//") ? "https:" + raw : raw) else { throw ShelfError.parse("stream URL") }
            return VideoStream(name: $0.name, url: url)
        }
    }
    private nonisolated static func quality(_ name: String) -> Int { name == "Source" ? Int.max : (Int(name) ?? 0) }
    private struct Login: Encodable { let email: String; let password: String }
    private struct UserToken: Decodable { let token: String }
    private struct AccessToken: Decodable { let accessToken: String }
    private struct List: Decodable { let count: Int; let limit: Int; let page: Int; let results: [Item] }
    private struct Stream: Decodable { let name: String; let src: Location
        struct Location: Decodable { let view: String?; let download: String? }
    }
    private struct Item: Decodable {
        let id: String; let title: String; let body: String?; let thumbnail: Int?
        let user: User; let file: File?; let customThumbnail: File?; let fileUrl: URL?; let tags: [Tag]?
        struct User: Decodable { let name: String }
        struct File: Decodable { let id: String; let name: String?; let duration: Double? }
        struct Tag: Decodable { let id: String }
        var video: Video {
            let image: URL?
            if let customThumbnail, let name = customThumbnail.name {
                image = URL(string: "https://i.iwara.tv/image/original/\(customThumbnail.id)/\(name)")
            } else if let file {
                image = URL(string: "https://i.iwara.tv/image/thumbnail/\(file.id)/thumbnail-\(String(format: "%02d", thumbnail ?? 0)).jpg")
            } else { image = nil }
            return Video(id: id, title: title, author: user.name, duration: file?.duration, thumbnail: image, description: body ?? "", tags: tags?.map(\.id) ?? [], fileURL: fileUrl)
        }
    }
}
