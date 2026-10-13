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
    private var expirationHandler: (@Sendable () async -> Void)?
    public func setExpirationHandler(_ action: @escaping @Sendable () async -> Void) { expirationHandler = action }
    public var hasSession: Bool { userToken != nil }
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
        do { guard try await bearer() != nil else { throw ShelfError.message("登录凭证已失效，请重新登录") } } catch { setUserToken(nil); throw error }
        return reply.token
    }
    private func bearer() async throws -> String? {
        guard let userToken else { return nil }
        if let accessToken, accessExpiry > Date() { return accessToken }
        let generation = authGeneration
        var request = HTTPClient.request(Self.url("user/token"), headers: ["Authorization": "Bearer \(userToken)", "Content-Type": "application/json"])
        request.httpMethod = "POST"; request.httpBody = Data()
        do {
            let reply = try JSONDecoder().decode(AccessToken.self, from: await http.data(for: request))
            guard generation == authGeneration else { throw CancellationError() }
            accessToken = reply.accessToken
            accessExpiry = try Self.tokenExpiry(reply.accessToken).addingTimeInterval(-60)
            return reply.accessToken
        } catch ShelfError.http(let status) where status == 401 || status == 403 {
            guard generation == authGeneration else { throw CancellationError() }
            setUserToken(nil)
            await expirationHandler?()
            return nil
        }
    }
    public nonisolated static func tokenExpiry(_ token: String) throws -> Date {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { throw ShelfError.parse("access token JWT") }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload) else { throw ShelfError.parse("JWT payload") }
        struct Claims: Decodable { let exp: Double }
        return Date(timeIntervalSince1970: try JSONDecoder().decode(Claims.self, from: data).exp)
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
    public func videos(page: Int = 0, sort: String = "date", rating: String = "all", query: String = "", category: String = "") async throws -> Page<Video> {
        var params = [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "limit", value: "24"), URLQueryItem(name: "sort", value: sort), URLQueryItem(name: "rating", value: rating)]
        if !query.isEmpty { params = [.init(name: "type", value: "videos"), .init(name: "query", value: query), .init(name: "page", value: String(page))] }
        return try Self.parseList(await api(query.isEmpty ? "videos" : "search", query: params))
    }
    public func filteredVideos(_ filter: VideoFilter, page: Int) async throws -> Page<Video> {
        switch filter {
        case .query(let query): return try await videos(page: page, query: query)
        case .author(let value), .tag(let value):
            let key: String
            if case .author = filter { key = "user" } else { key = "tags" }
            return try Self.parseList(await api("videos", query: [.init(name: key, value: value), .init(name: "page", value: String(page)), .init(name: "limit", value: "24"), .init(name: "sort", value: "date")]))
        }
    }
    public func creatorVideos(for video: Video) async throws -> [Video] {
        guard let author = video.authorID else { return [] }
        return try await filteredVideos(.author(author), page: 0).items.filter { $0.id != video.id }.prefix(12).map { $0 }
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
    public nonisolated static func parseVideo(_ data: Data) throws -> Video { try JSONDecoder().decode(Item.self, from: data).makeVideo(detail: true) }
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
        let createdAt: String?; let numViews: Int?; let numLikes: Int?; let numComments: Int?; let rating: String?; let embedUrl: URL?
        struct User: Decodable { let id: String?; let name: String }
        struct File: Decodable { let id: String; let name: String?; let duration: Double?; let width: Int?; let height: Int? }
        struct Tag: Decodable { let id: String }
        var video: Video { makeVideo(detail: false) }
        func makeVideo(detail: Bool) -> Video {
            let image: URL?
            if let customThumbnail, let name = customThumbnail.name {
                image = URL(string: "https://i.iwara.tv/image/\(detail ? "original" : "large")/\(customThumbnail.id)/\(name)")
            } else if let file {
                image = URL(string: "https://i.iwara.tv/image/thumbnail/\(file.id)/thumbnail-\(String(format: "%02d", thumbnail ?? 0)).jpg")
            } else { image = nil }
            var video = Video(id: id, title: title, author: user.name, duration: file?.duration, thumbnail: image, description: body ?? "", tags: tags?.map(\.id) ?? [], fileURL: fileUrl)
            video.width = file?.width; video.height = file?.height
            video.createdAt = createdAt; video.numViews = numViews; video.numLikes = numLikes; video.numComments = numComments
            video.rating = rating; video.authorID = user.id; video.embedURL = embedUrl
            video.tagLinks = video.tags.map { BrowseTag(title: $0, value: $0) }
            return video
        }
    }
}
