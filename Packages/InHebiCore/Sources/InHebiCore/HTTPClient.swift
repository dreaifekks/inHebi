import Foundation

public struct HTTPClient: Sendable {
    public static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
    public let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }
    public static func request(_ url: URL, headers: [String: String] = [:]) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        return request
    }
    public func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw InHebiError.parse("HTTP response") }
        guard (200...299).contains(response.statusCode) else { throw InHebiError.http(response.statusCode) }
        return data
    }
    public func data(_ url: URL, headers: [String: String] = [:]) async throws -> Data {
        try await data(for: Self.request(url, headers: headers))
    }
}
