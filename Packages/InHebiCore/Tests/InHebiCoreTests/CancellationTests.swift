import XCTest
@testable import InHebiCore

private final class PendingImageProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var started: XCTestExpectation!
    nonisolated(unsafe) static var stopped: XCTestExpectation!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.started.fulfill() }
    override func stopLoading() { Self.stopped.fulfill() }
}
@MainActor final class CancellationTests: XCTestCase {
    func testCancellingImageConsumerStopsURLSessionRequest() async throws {
        PendingImageProtocol.started = expectation(description: "Image request started")
        PendingImageProtocol.stopped = expectation(description: "Image request stopped")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PendingImageProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let task = Task { try await HTTPClient(session: session).data(URL(string: "https://fixture.invalid/image")!) }
        await fulfillment(of: [PendingImageProtocol.started], timeout: 2)
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled request completed") }
        catch let error as URLError { XCTAssertEqual(error.code, .cancelled) }
        await fulfillment(of: [PendingImageProtocol.stopped], timeout: 2)
    }
}
