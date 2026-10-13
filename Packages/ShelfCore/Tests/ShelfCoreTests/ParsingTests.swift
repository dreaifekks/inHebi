import XCTest
@testable import ShelfCore

final class ParsingTests: XCTestCase {
    func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!)
    }
    func html(_ name: String) throws -> String { String(decoding: try fixture(name), as: UTF8.self) }
    func testIwaraListAndDetail() throws {
        let list = try IwaraSource.parseList(fixture("iwara-list.json"))
        XCTAssertEqual(list.items.count, 2)
        XCTAssertEqual(list.nextPage, 1)
        let detail = try IwaraSource.parseVideo(fixture("iwara-detail.json"))
        XCTAssertEqual(detail.id, list.items[0].id)
        XCTAssertEqual(detail.duration, 110)
        XCTAssertTrue(detail.thumbnail!.absoluteString.hasSuffix("thumbnail-07.jpg"))
        XCTAssertTrue(detail.tags.contains("mikumikudance"))
        XCTAssertNotNil(detail.fileURL)
    }
    func testStreamsSortedAndNormalized() throws {
        let streams = try IwaraSource.parseStreams(fixture("iwara-streams.json"))
        XCTAssertEqual(streams.map(\.name), ["Source", "540", "360", "preview"])
        XCTAssertTrue(streams.allSatisfy { $0.url.scheme == "https" })
        XCTAssertThrowsError(try IwaraSource.version(for: URL(string: "https://example.com/file/id")!))
        XCTAssertEqual(try IwaraSource.version(for: URL(string: "https://example.com/file/abc?expires=123")!), "ffc951f53b47a7269a0577b4ae0b9bd40e7fb017")
    }
    func testWnacgListCategoriesAndDetail() throws {
        let html = try html("wnacg-list.html")
        let list = try WnacgSource.parseList(html, page: 1)
        XCTAssertEqual(list.items.count, 20)
        XCTAssertEqual(list.items.first?.id, "395652")
        XCTAssertEqual(list.nextPage, 2)
        XCTAssertFalse(list.items[0].title.isEmpty)
        let categories = try WnacgSource.parseCategories(html)
        XCTAssertTrue(categories.contains { $0.id == "1" && $0.title == "漢化" })
        XCTAssertEqual(Set(categories.map(\.id)).count, categories.count)
        let detail = try WnacgSource.parseAlbum(self.html("wnacg-detail.html"), id: "395652")
        XCTAssertEqual(detail.pageCount, 11)
        XCTAssertEqual(detail.cover?.host, "t4.qy0.ru")
        XCTAssertEqual(detail.cover?.scheme, "https")
    }
    func testGalleryDecodesJSAndExcludesPromotion() throws {
        let pages = try WnacgSource.parsePages(html("wnacg-gallery.html"))
        XCTAssertEqual(pages.count, 11)
        XCTAssertTrue(pages[0].path.hasSuffix("0001.webp"))
        XCTAssertTrue(pages[10].path.hasSuffix("0011.webp"))
        XCTAssertTrue(pages.allSatisfy { $0.scheme == "https" && !$0.path.contains("themes") })
        XCTAssertThrowsError(try WnacgSource.parsePages("<html>challenge</html>"))
    }
    func testRealSearchResponses() throws {
        let videos = try IwaraSource.parseList(fixture("iwara-search.json"))
        XCTAssertEqual(videos.items.count, 32)
        XCTAssertEqual(videos.nextPage, 1)
        let albums = try WnacgSource.parseList(html("wnacg-search.html"), page: 2)
        XCTAssertFalse(albums.items.isEmpty)
        XCTAssertEqual(albums.nextPage, 3)
    }
    func testIwaraPaginationLowerBoundAndCustomThumbnail() throws {
        let page = try IwaraSource.parseList(fixture("iwara-page-1.json"))
        XCTAssertEqual(page.items.count, 24)
        XCTAssertEqual(page.nextPage, 2)
        let custom = try XCTUnwrap(page.items.first { $0.thumbnail?.path.contains("/original/") == true })
        XCTAssertEqual(custom.thumbnail?.host, "i.iwara.tv")
    }
    func testReaderOrderAndBounds() {
        XCTAssertEqual(ReaderLayout.visibleIndices(page: 0, count: 5, spread: true), [1, 0])
        XCTAssertEqual(ReaderLayout.visibleIndices(page: 4, count: 5, spread: true), [4])
        XCTAssertEqual(ReaderLayout.visibleIndices(page: 2, count: 5, spread: false), [2])
        XCTAssertEqual(ReaderLayout.advanced(page: 0, count: 5, spread: true, forward: false), 0)
        XCTAssertEqual(ReaderLayout.advanced(page: 2, count: 5, spread: true, forward: true), 4)
        XCTAssertEqual(ReaderLayout.advanced(page: 4, count: 5, spread: true, forward: true), 4)
        XCTAssertEqual(ReaderLayout.advanced(page: 4, count: 6, spread: true, forward: true), 4)
    }
    func testSearchEncodingAndPagination() {
        let url = WnacgSource.listURL(page: 2, category: "", query: "a & b")
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(query.first { $0.name == "q" }?.value, "a & b")
        XCTAssertEqual(query.first { $0.name == "p" }?.value, "2")
    }
}
