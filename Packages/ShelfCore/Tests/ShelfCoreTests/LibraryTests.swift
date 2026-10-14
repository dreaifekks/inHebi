import SwiftData
import XCTest

@testable import ShelfCore

@MainActor final class LibraryTests: XCTestCase {
  private func store() throws -> LibraryStore {
    LibraryStore(container: try LibraryStore.makeContainer(inMemory: true))
  }
  private let video = LibraryMetadata(source: "iwara", mediaID: "42", title: "A")
  func testHistoryDeduplicatesBySourceAndID() throws {
    let store = try store()
    try store.recordVisit(video, at: Date(timeIntervalSince1970: 1))
    try store.recordVisit(video, at: Date(timeIntervalSince1970: 2))
    try store.recordVisit(LibraryMetadata(source: "Hanime1", mediaID: "42", title: "B"))
    XCTAssertEqual(try store.items().count, 2)
    XCTAssertEqual(try store.item(key: video.key)?.lastViewedAt, Date(timeIntervalSince1970: 2))
  }
  func testReadingPageAndClearHistoryPreserveFavorites() throws {
    let store = try store()
    let album = LibraryMetadata(source: "wnacg", mediaID: "7", title: "Book", isComic: true)
    try store.recordVisit(album, page: 3)
    try store.saveReadingPage(8, key: album.key)
    XCTAssertEqual(try store.lastPage(key: album.key), 8)
    try store.toggleDefault(album)
    try store.clearHistory()
    XCTAssertNil(try store.item(key: album.key)?.lastViewedAt)
    XCTAssertEqual(try store.lastPage(key: album.key), 0)
    XCTAssertEqual(try store.item(key: album.key)?.folders?.count, 1)
  }
  func testMultipleFoldersCreateRenameDeleteAndToggle() throws {
    let store = try store()
    let a = try store.createFolder(name: "A")
    let b = try store.createFolder(name: "B")
    try store.toggle(video, in: a)
    try store.toggle(video, in: b)
    XCTAssertEqual(try store.item(key: video.key)?.folders?.count, 2)
    XCTAssertEqual(a.items?.count, 1)
    try store.rename(a, to: "Renamed")
    XCTAssertEqual(a.name, "Renamed")
    try store.toggle(video, in: a)
    XCTAssertEqual(try store.item(key: video.key)?.folders?.count, 1)
    try store.delete(b)
    XCTAssertEqual(try store.folders().count, 1)
    XCTAssertTrue(try store.item(key: video.key)?.folders?.isEmpty ?? true)
    XCTAssertEqual(try store.items().count, 1)
  }
  func testDefaultFolderIsLazyAndRecreatedAfterDeletion() throws {
    let store = try store()
    XCTAssertTrue(try store.folders().isEmpty)
    try store.toggleDefault(video)
    try store.toggleDefault(video)
    XCTAssertEqual(try store.folders().count, 1)
    XCTAssertTrue(try store.item(key: video.key)?.folders?.isEmpty ?? true)
    try store.delete(try store.defaultFolder())
    try store.toggleDefault(video)
    XCTAssertEqual(try store.folders().count, 1)
    XCTAssertEqual(try store.defaultFolder().name, "默认收藏")
  }
  func testMetadataRefreshDoesNotCreateHistoryOrLoseMembership() throws {
    let store = try store()
    try store.toggleDefault(video)
    let fresh = LibraryMetadata(
      source: "iwara", mediaID: "42", title: "Fresh", cover: "https://example.com/new")
    try store.refresh(fresh)
    let item = try XCTUnwrap(store.item(key: fresh.key))
    XCTAssertEqual(item.title, "Fresh")
    XCTAssertEqual(item.cover, fresh.cover)
    XCTAssertNil(item.lastViewedAt)
    XCTAssertEqual(item.folders?.count, 1)
    try store.refresh(LibraryMetadata(source: "iwara", mediaID: "unknown", title: "Not saved"))
    XCTAssertEqual(try store.items().count, 1)
  }
  func testConcurrentCloudInsertsMergeHistoryAndMemberships() throws {
    let store = try store()
    let folderA = FavoriteFolder(name: "默认收藏", folderID: "default")
    let folderB = FavoriteFolder(name: "默认收藏", folderID: "default")
    store.context.insert(folderA)
    store.context.insert(folderB)
    let a = SavedMediaItem(video)
    let b = SavedMediaItem(video)
    store.context.insert(a)
    store.context.insert(b)
    a.lastViewedAt = Date(timeIntervalSince1970: 1)
    b.lastViewedAt = Date(timeIntervalSince1970: 2)
    b.readingPage = 9
    a.folders = [folderA]
    b.folders = [folderB]
    try store.context.save()
    try store.reconcileDuplicates()
    XCTAssertEqual(try store.items().count, 1)
    XCTAssertEqual(try store.folders().count, 1)
    XCTAssertEqual(try store.item(key: video.key)?.readingPage, 9)
    XCTAssertEqual(try store.item(key: video.key)?.folders?.count, 1)
  }
}
