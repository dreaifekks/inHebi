import XCTest
@testable import ShelfCore

@MainActor final class PagerTests: XCTestCase {
    struct Item: Identifiable, Sendable { let id: Int }
    func testReappearingPreservesPagesUntilFilterChanges() async {
        let pager = Pager<Item>()
        var calls: [Int] = []
        func fetch(_ page: Int) async throws -> Page<Item> {
            calls.append(page)
            return Page(items: [Item(id: page)], nextPage: page + 1)
        }
        await pager.load(reset: true, key: "date", first: 0, fetch: fetch)
        await pager.load(key: "date", first: 0, fetch: fetch)
        await pager.load(reset: true, key: "date", first: 0, fetch: fetch)
        XCTAssertEqual(calls, [0, 1])
        XCTAssertEqual(pager.items.map(\.id), [0, 1])
        await pager.load(reset: true, key: "views", first: 0, fetch: fetch)
        XCTAssertEqual(calls, [0, 1, 0])
        XCTAssertEqual(pager.items.map(\.id), [0])
    }
    func testURLSessionCancellationLeavesNoErrorAndCanResume() async {
        let pager = Pager<Item>()
        await pager.load(reset: true, key: "all", first: 1) { _ in throw URLError(.cancelled) }
        XCTAssertNil(pager.error)
        XCTAssertFalse(pager.loading)
        await pager.load(reset: true, key: "all", first: 1) { page in Page(items: [Item(id: page)], nextPage: nil) }
        XCTAssertEqual(pager.items.map(\.id), [1])
    }
    func testEmptyCompletedPageCanReloadOnReappearance() async {
        let pager = Pager<Item>()
        await pager.load(reset: true, key: "empty", first: 0) { _ in Page(items: [], nextPage: nil) }
        await pager.load(reset: true, key: "empty", first: 0) { _ in Page(items: [Item(id: 1)], nextPage: nil) }
        XCTAssertEqual(pager.items.map(\.id), [1])
        XCTAssertEqual(pager.requestCount, 2)
    }

    func testChangedFilterCancelsRunningRequest() async {
        let pager = Pager<Item>()
        let started = expectation(description: "old request started")
        let cancelled = expectation(description: "old request cancelled")
        let old = Task {
            await pager.load(key: "old", first: 0) { _ in
                started.fulfill()
                do { try await Task.sleep(for: .seconds(30)) }
                catch { cancelled.fulfill(); throw error }
                return Page(items: [Item(id: 1)], nextPage: nil)
            }
        }
        await fulfillment(of: [started], timeout: 1)
        await pager.load(reset: true, key: "new", first: 0) { _ in
            Page(items: [Item(id: 2)], nextPage: nil)
        }
        await old.value
        await fulfillment(of: [cancelled], timeout: 1)
        XCTAssertEqual(pager.items.map(\.id), [2])
        XCTAssertNil(pager.error)
    }
    func testLateResultCannotReplaceNewFilter() async {
        let pager = Pager<Item>()
        let started = expectation(description: "old suspended")
        var reply: CheckedContinuation<Page<Item>, Never>?
        let old = Task {
            await pager.load(key: "old", first: 0) { _ in
                await withCheckedContinuation { continuation in
                    reply = continuation
                    started.fulfill()
                }
            }
        }
        await fulfillment(of: [started], timeout: 1)
        await pager.load(reset: true, key: "new", first: 0) { _ in
            Page(items: [Item(id: 2)], nextPage: nil)
        }
        reply!.resume(returning: Page(items: [Item(id: 1)], nextPage: 1))
        await old.value
        XCTAssertEqual(pager.items.map(\.id), [2])
        XCTAssertNil(pager.next)
    }

}
