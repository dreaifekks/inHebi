import XCTest
@testable import InHebiCore

/// A per-session URLProtocol fake; these obvious fixture strings are not real credentials.
final class AuthProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (code, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}
@MainActor final class AuthTests: XCTestCase {
    func testLoginRefreshAndLogoutRequests() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); AuthProtocol.handler = nil }
        let source = IwaraSource(http: HTTPClient(session: session))
        var exchanges = 0
        var videoRequests = 0
        let lock = NSLock()
        AuthProtocol.handler = { request in
            lock.lock(); defer { lock.unlock() }
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), HTTPClient.userAgent)
            switch request.url!.path {
            case "/user/login":
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
                return (200, Data(#"{"token":"fixture-user-token"}"#.utf8))
            case "/user/token":
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-user-token")
                exchanges += 1
                return (200, Data("{\"accessToken\":\"\(fixtureJWT(exchanges))\"}".utf8))
            case "/videos":
                videoRequests += 1
                let auth = request.value(forHTTPHeaderField: "Authorization")
                if videoRequests == 1 {
                    XCTAssertEqual(auth, "Bearer " + fixtureJWT(1))
                    return (401, Data())
                }
                if videoRequests == 2 { XCTAssertEqual(auth, "Bearer " + fixtureJWT(2)) }
                if videoRequests == 3 { XCTAssertNil(auth) }
                return (200, Data(#"{"count":0,"limit":24,"page":0,"results":[]}"#.utf8))
            default: throw InHebiError.message("Unexpected test request")
            }
        }
        let token = try await source.login(email: "fixture@example.invalid", password: "fixture-password")
        XCTAssertEqual(token, "fixture-user-token")
        _ = try await source.videos()
        await source.setUserToken(nil)
        _ = try await source.videos()
        XCTAssertEqual(exchanges, 2)
        XCTAssertEqual(videoRequests, 3)
    }
}

func fixtureJWT(_ sequence: Int, expires: TimeInterval = 4_102_444_800) -> String {
    let payload = Data("{\"exp\":\(Int(expires))}".utf8).base64EncodedString()
        .replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    return "fixture.\(payload).signature-\(sequence)"
}

extension AuthTests {
    func testRejectedUserTokenFallsBackToGuestAndNotifies() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); AuthProtocol.handler = nil }
        let source = IwaraSource(http: HTTPClient(session: session))
        let expired = expectation(description: "Account expiration notification")
        await source.setExpirationHandler { expired.fulfill() }
        await source.setUserToken("fixture-expired-user")
        AuthProtocol.handler = { request in
            if request.url!.path == "/user/token" { return (403, Data()) }
            XCTAssertEqual(request.url!.path, "/videos")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            return (200, Data(#"{"count":0,"limit":24,"page":0,"results":[]}"#.utf8))
        }
        _ = try await source.videos()
        await fulfillment(of: [expired], timeout: 1)
        let hasSession = await source.hasSession
        XCTAssertFalse(hasSession)
        _ = try await source.videos()
    }
    func testJWTExpiryRefreshesWithoutServer401() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); AuthProtocol.handler = nil }
        let source = IwaraSource(http: HTTPClient(session: session))
        await source.setUserToken("fixture-user")
        var exchanges = 0
        let lock = NSLock()
        AuthProtocol.handler = { request in
            lock.lock(); defer { lock.unlock() }
            if request.url!.path == "/user/token" {
                exchanges += 1
                let token = fixtureJWT(exchanges, expires: exchanges == 1 ? 1 : 4_102_444_800)
                return (200, Data("{\"accessToken\":\"\(token)\"}".utf8))
            }
            // The real API can return HTTP 200 as a guest even for a bad access token.
            return (200, Data(#"{"count":0,"limit":24,"page":0,"results":[]}"#.utf8))
        }
        _ = try await source.videos()
        _ = try await source.videos()
        XCTAssertEqual(exchanges, 2)
        XCTAssertEqual(try IwaraSource.tokenExpiry(fixtureJWT(1, expires: 1234)).timeIntervalSince1970, 1234)
    }
}
