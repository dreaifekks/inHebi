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

}
