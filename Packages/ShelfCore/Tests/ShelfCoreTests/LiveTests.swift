import XCTest
import ImageIO
@testable import ShelfCore

@MainActor final class LiveTests: XCTestCase {
    func enabled() throws { try XCTSkipUnless(ProcessInfo.processInfo.environment["SHELF_LIVE_TESTS"] == "1", "Set SHELF_LIVE_TESTS=1 to contact live sites") }
    func testIwaraLive() async throws {
        try enabled()
        let source = IwaraSource()
        let list = try await source.videos()
        let first = try XCTUnwrap(list.items.first)
        let detail = try await source.video(id: first.id)
        XCTAssertEqual(detail.id, first.id)
        let streams = try await source.streams(for: detail)
        let best = try XCTUnwrap(streams.first)
        var request = HTTPClient.request(best.url)
        request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        // Streaming response avoids downloading an entire video if Range is ignored.
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let code = try XCTUnwrap(response as? HTTPURLResponse).statusCode
        XCTAssertTrue([200, 206].contains(code))
        var received = 0
        for try await _ in bytes { received += 1; if received == 1024 { break } }
        XCTAssertGreaterThan(received, 0)
        let thumbnail = try XCTUnwrap(detail.thumbnail)
        let image = try await HTTPClient().data(thumbnail)
        XCTAssertGreaterThan(image.count, 100)
        print("LIVE iwara list=\(list.items.count), detail OK, qualities=\(streams.map(\.name)), video HTTP \(code), bytes=\(received), thumbnail bytes=\(image.count)")
        let search = try await source.videos(query: "MMD")
        print("LIVE iwara search=\(search.items.count)")
        let byAuthor = try await source.filteredVideos(.author(XCTUnwrap(detail.authorID)), page: 0)
        XCTAssertTrue(byAuthor.items.allSatisfy { $0.authorID == detail.authorID })
        let tag = try XCTUnwrap(detail.tags.first)
        let byTag = try await source.filteredVideos(.tag(tag), page: 0)
        XCTAssertTrue(byTag.items.allSatisfy { $0.tags.contains(tag) })
        let expired = IwaraSource()
        await expired.setUserToken("fixture-invalid-user-token")
        let guest = try await expired.videos()
        let hasSession = await expired.hasSession
        XCTAssertFalse(hasSession)
        XCTAssertFalse(guest.items.isEmpty)
        print("LIVE iwara author/tag and expired-session guest fallback OK")
    }
    func testWnacgLive() async throws {
        try enabled()
        let source = WnacgSource()
        let list = try await source.albums()
        let first = try XCTUnwrap(list.items.first)
        let detail = try await source.album(id: first.id)
        let pages = try await source.pages(id: first.id)
        let imageURL = try XCTUnwrap(pages.first)
        let request = HTTPClient.request(imageURL, headers: ["Referer": source.imageReferer(albumID: first.id)])
        let (image, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertTrue((response.mimeType ?? "").hasPrefix("image/"))
        XCTAssertGreaterThan(image.count, 1000)
        let imageSource = try XCTUnwrap(CGImageSourceCreateWithData(image as CFData, nil))
        XCTAssertNotNil(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
        XCTAssertEqual(pages.count, detail.pageCount)
        let categories = try await source.categories()
        XCTAssertFalse(categories.isEmpty)
        let category = try await source.albums(page: 2, category: "1")
        XCTAssertFalse(category.items.isEmpty)
        let search = try await source.albums(query: "original")
        XCTAssertFalse(search.items.isEmpty)
        let tag = try XCTUnwrap(detail.tags.first)
        let tagged = try await source.albums(tag: tag.value)
        XCTAssertFalse(tagged.items.isEmpty)
        print("LIVE wnacg list=\(list.items.count), pages=\(pages.count), first image HTTP 200 bytes=\(image.count), categories=\(categories.count), category page2=\(category.items.count), search=\(search.items.count)")
    }
    func testHanime1Live() async throws {
        try enabled()
        let source = Hanime1Source()
        let list = try await source.videos()
        XCTAssertFalse(list.items.isEmpty)
        let second = try await source.videos(page: 1)
        XCTAssertFalse(second.items.isEmpty)
        XCTAssertNotEqual(list.items.first?.id, second.items.first?.id)
        let portrait = try await source.videos(category: "裏番")
        XCTAssertTrue(try XCTUnwrap(portrait.items.first).isPortrait)
        let search = try await source.videos(query: "MMD", category: "MMD")
        XCTAssertFalse(search.items.isEmpty)
        let detail = try await source.video(id: XCTUnwrap(search.items.first).id)
        let streams = try await source.streams(for: detail)
        let best = try XCTUnwrap(streams.first)
        var request = HTTPClient.request(best.url)
        request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let code = try XCTUnwrap(response as? HTTPURLResponse).statusCode
        XCTAssertTrue([200, 206].contains(code))
        XCTAssertEqual(response.mimeType, "video/mp4")
        var received = 0
        for try await _ in bytes { received += 1; if received == 1024 { break } }
        XCTAssertEqual(received, 1024)
        let thumbnail = try XCTUnwrap(detail.thumbnail)
        let image = try await HTTPClient().data(thumbnail)
        XCTAssertNotNil(CGImageSourceCreateWithData(image as CFData, nil))
        print("LIVE Hanime1 list=\(list.items.count), page2=\(second.items.count), portrait=\(portrait.items.count), search=\(search.items.count), qualities=\(streams.map(\.name)), video HTTP \(code), bytes=\(received), thumbnail bytes=\(image.count)")
    }

}
