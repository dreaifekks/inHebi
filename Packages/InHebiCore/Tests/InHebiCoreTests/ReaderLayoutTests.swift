import XCTest
@testable import InHebiCore

final class ReaderLayoutTests: XCTestCase {
    func testSelectedPageStartsSpreadInEitherDirection() {
        for start in [0, 1, 4, 5] {
            XCTAssertEqual(ReaderLayout.visibleIndices(page: start, count: 11, spread: true), [start + 1, start])
            XCTAssertEqual(ReaderLayout.visibleIndices(page: start, count: 11, spread: true, rightToLeft: false), [start, start + 1])
            XCTAssertEqual(ReaderLayout.visibleIndices(page: start, count: 11, spread: false), [start])
        }
    }

    func testJumpAndResumePreserveAnchorWhileTurning() {
        // Resume at page 6, then visit 8/9 and return to 6/7 without parity alignment.
        let resumed = 5
        let next = ReaderLayout.advanced(page: resumed, count: 11, spread: true, forward: true)
        XCTAssertEqual(next, 7)
        XCTAssertEqual(ReaderLayout.visibleIndices(page: next, count: 11, spread: true), [8, 7])
        XCTAssertEqual(ReaderLayout.advanced(page: next, count: 11, spread: true, forward: false), resumed)
        XCTAssertEqual(ReaderLayout.advanced(page: 1, count: 11, spread: true, forward: false), 0)
        XCTAssertEqual(ReaderLayout.advanced(page: 0, count: 11, spread: true, forward: false), 0)
    }

    func testLastSpreadAndPrefetchUseSelectedAnchor() {
        XCTAssertEqual(ReaderLayout.prefetchIndices(page: 5, count: 11, spread: true), 7..<11)
        XCTAssertEqual(ReaderLayout.prefetchIndices(page: 5, count: 11, spread: false), 6..<11)
        XCTAssertEqual(ReaderLayout.visibleIndices(page: 9, count: 11, spread: true), [10, 9])
        XCTAssertEqual(ReaderLayout.advanced(page: 9, count: 11, spread: true, forward: true), 9)
        XCTAssertEqual(ReaderLayout.prefetchIndices(page: 9, count: 11, spread: true), 11..<11)
        XCTAssertEqual(ReaderLayout.visibleIndices(page: 10, count: 11, spread: true), [10])
        XCTAssertEqual(ReaderLayout.prefetchIndices(page: 10, count: 11, spread: true), 11..<11)
        XCTAssertEqual(ReaderLayout.visibleIndices(page: 0, count: 0, spread: true), [])
        XCTAssertEqual(ReaderLayout.prefetchIndices(page: 0, count: 0, spread: true), 0..<0)
    }
}
