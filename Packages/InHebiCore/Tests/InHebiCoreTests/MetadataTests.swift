import XCTest
@testable import InHebiCore

final class MetadataTests: XCTestCase {
    func data(_ file: String) throws -> Data { try Data(contentsOf: Bundle.module.url(forResource: file, withExtension: nil, subdirectory: "Fixtures")!) }
    func html(_ file: String) throws -> String { String(decoding: try data(file), as: UTF8.self) }
    func testIwaraStatisticsAndNavigationMetadata() throws {
        let video = try IwaraSource.parseVideo(data("iwara-detail.json"))
        XCTAssertEqual(video.numViews, 1)
        XCTAssertEqual(video.numLikes, 0)
        XCTAssertEqual(video.numComments, 0)
        XCTAssertEqual(video.width, 1920)
        XCTAssertEqual(video.height, 1080)
        XCTAssertEqual(video.rating, "general")
        XCTAssertNotNil(video.authorID)
        XCTAssertEqual(video.createdAt, "2026-10-13T17:10:15.000Z")
        XCTAssertEqual(video.tagLinks.map(\.value), video.tags)
    }
    func testHanimeMetadataCreatorAndRelatedCards() throws {
        let video = try Hanime1Source.parseVideo(html("hanime-detail.html"), id: "408185")
        XCTAssertEqual(video.viewsText, "85.2万次")
        XCTAssertEqual(video.createdAt, "2026-10-10")
        XCTAssertEqual(video.categoryText, "3DCG")
        XCTAssertTrue(video.feedbackText?.contains("8906") == true)
        XCTAssertEqual(video.authorSectionTitle, "社團 Ubermation")
        XCTAssertFalse(video.authorVideos.isEmpty)
        XCTAssertEqual(video.relatedVideos.count, 12)
        XCTAssertTrue((video.authorVideos + video.relatedVideos).allSatisfy { !$0.title.isEmpty && $0.thumbnail != nil && $0.id != video.id })
        XCTAssertTrue(video.tagLinks.contains { $0.usesSearch })
        XCTAssertTrue(video.tagLinks.contains { !$0.usesSearch && $0.value == "1080p" })
        let list = try Hanime1Source.parseList(html("hanime-list.html"), page: 0)
        XCTAssertNotNil(list.items[0].viewsText)
        XCTAssertFalse(list.items[0].createdAt!.isEmpty)
    }
    func testWnacgHierarchyAndPreviewMetadata() throws {
        let categories = try WnacgSource.parseCategories(html("wnacg-list.html"))
        XCTAssertEqual(categories.map(\.id), ["5", "6", "7", "19"])
        let flat = categories.flatMap(\.flattened)
        XCTAssertEqual(flat.count, categories.count + categories.reduce(0) { $0 + $1.children.count })
        XCTAssertEqual(Array(flat.prefix(3)).map(\.title), ["同人誌", "同人誌·漢化", "同人誌·日語"])
        XCTAssertEqual(Set(flat.map(\.id)).count, flat.count)
        XCTAssertEqual(flat.last?.id, categories.last?.children.last?.id ?? categories.last?.id)
        XCTAssertEqual(categories[0].children.map(\.id), ["1", "12", "16", "2", "37", "22", "3"])
        XCTAssertEqual(categories[1].children.first?.title, "漢化")
        XCTAssertNotEqual(categories[0].children.first?.id, categories[1].children.first?.id)
        let album = try WnacgSource.parseAlbum(html("wnacg-detail.html"), id: "395652")
        XCTAssertEqual(album.categoryText, "同人誌／漢化")
        XCTAssertEqual(album.createdAt, "2026-10-13")
        XCTAssertFalse(album.tags.isEmpty)
        XCTAssertEqual(album.previews.count, 11)
        XCTAssertEqual(album.previews.first?.host, "t4.qy0.ru")
        let list = try WnacgSource.parseList(html("wnacg-list.html"), page: 1)
        XCTAssertEqual(list.items[0].pageCount, 11)
        XCTAssertEqual(list.items[0].createdAt, "2026-10-13")
    }
}
