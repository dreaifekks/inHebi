import XCTest
import SwiftSoup
@testable import ShelfCore

final class Hanime1Tests: XCTestCase {
    func html(_ name: String) throws -> String {
        try String(contentsOf: Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Fixtures")!, encoding: .utf8)
    }
    func testFormValuesMatchSourceOptions() throws {
        let doc = try SwiftSoup.parse(html("hanime-list"))
        let genres = try doc.select(".genre-option[data-value]").map { try $0.attr("data-value") }
        let sorts = try doc.select("#sort-modal .hentai-sort-options-wrapper[data-value]").map { try $0.attr("data-value") }
        let source = Hanime1Source()
        XCTAssertEqual(["全部"] + source.categories.dropFirst().map(\.id), genres)
        XCTAssertEqual(source.sorts.map(\.id), sorts)
        XCTAssertTrue(source.supportsSearchFilters)
        XCTAssertTrue(source.ratings.isEmpty)
    }
    func testLandscapeListExcludesAdsAndDeduplicates() throws {
        let page = try Hanime1Source.parseList(html("hanime-list"), page: 0)
        XCTAssertEqual(page.items.count, 59)
        XCTAssertEqual(page.nextPage, 1)
        XCTAssertEqual(Set(page.items.map(\.id)).count, page.items.count)
        XCTAssertTrue(page.items.allSatisfy { !$0.title.isEmpty && $0.thumbnail != nil })
        XCTAssertFalse(page.items[0].isPortrait)
        XCTAssertEqual(page.items[0].duration, 988)
        XCTAssertEqual(page.items[0].author, "ADLER")
    }
    func testPortraitListAndEmptyCategory() throws {
        let page = try Hanime1Source.parseList(html("hanime-portrait"), page: 0)
        XCTAssertEqual(page.items.count, 41)
        XCTAssertTrue(page.items.allSatisfy(\.isPortrait))
        XCTAssertTrue(page.items.allSatisfy { !$0.title.isEmpty })
        XCTAssertEqual(page.nextPage, 1)
        let empty = try Hanime1Source.parseList(html("hanime-empty"), page: 0)
        XCTAssertTrue(empty.items.isEmpty)
        XCTAssertNil(empty.nextPage)
        XCTAssertThrowsError(try Hanime1Source.parseList("<html>Challenge</html>", page: 0))
    }
    func testDetailMetadataAndHighestQuality() throws {
        let video = try Hanime1Source.parseVideo(html("hanime-detail"), id: "408185")
        XCTAssertEqual(video.id, "408185")
        XCTAssertFalse(video.title.isEmpty)
        XCTAssertFalse(video.author.isEmpty)
        XCTAssertFalse(video.tags.isEmpty)
        XCTAssertTrue(video.tags.contains("1080p"))
        XCTAssertFalse(video.description.isEmpty)
        XCTAssertNotNil(video.duration)
        XCTAssertNotNil(video.thumbnail)
        XCTAssertEqual(video.availableStreams.map(\.name), ["1080p", "720p", "480p"])
        XCTAssertTrue(video.availableStreams[0].url.path.hasSuffix("408185-1080p.mp4"))
        let two = try Hanime1Source.parseStreams(html("hanime-two-streams"))
        XCTAssertEqual(two.map(\.name), ["720p", "480p"])
        XCTAssertThrowsError(try Hanime1Source.parseStreams("<video id='player'></video>"))
    }
    func testURLKeepsFiltersAndUsesOneBasedPage() throws {
        let url = Hanime1Source.listURL(page: 1, sort: "本週排行", query: "A & B", category: "Motion Anime")
        let params = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(params.first { $0.name == "query" }?.value, "A & B")
        XCTAssertEqual(params.first { $0.name == "genre" }?.value, "Motion Anime")
        XCTAssertEqual(params.first { $0.name == "sort" }?.value, "本週排行")
        XCTAssertEqual(params.first { $0.name == "page" }?.value, "2")
        XCTAssertEqual(url.host, "hanimeone.me")
    }
}
