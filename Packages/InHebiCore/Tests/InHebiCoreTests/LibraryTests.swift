import SwiftData
import XCTest

@testable import InHebiCore

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
    try store.updateReadingPage(8, key: album.key)
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
    XCTAssertNil(try store.item(key: video.key))
    XCTAssertEqual(try store.items().count, 0)
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
  func testStableMergeUsesCreationTimeThenRecordIDAcrossDevices() throws {
    for reverse in [false, true] {
      let store = try store()
      let ids = reverse ? ["b", "a", "z"] : ["z", "a", "b"]
      for id in ids {
        let item = SavedMediaItem(video)
        item.recordID = id
        item.createdAt = Date(timeIntervalSince1970: id == "z" ? 1 : 2)
        item.metadataUpdatedAt = Date(timeIntervalSince1970: (id == "a") == reverse ? 100 : 200)
        store.context.insert(item)
      }
      try store.context.save()
      try store.reconcileDuplicates()
      XCTAssertEqual(
        try store.item(key: video.key)?.recordID, "z",
        "Oldest identity wins even if metadata is refreshed")

      let existing = try XCTUnwrap(store.item(key: video.key))
      store.context.delete(existing)
      try store.context.save()
      for id in ["a", "b"].sorted(by: reverse ? (>) : (<)) {
        let item = SavedMediaItem(video)
        item.recordID = id
        item.createdAt = Date(timeIntervalSince1970: 3)
        item.metadataUpdatedAt = Date(timeIntervalSince1970: (id == "a") == reverse ? 100 : 200)
        store.context.insert(item)
      }
      try store.context.save()
      try store.reconcileDuplicates()
      XCTAssertEqual(
        try store.item(key: video.key)?.recordID, "a", "Equal creation times use a stable record ID"
      )
    }
  }
  func testDefaultFolderMergeBreaksCreationTimeTiesByRecordID() throws {
    let store = try store()
    for id in ["b", "a"] {
      let folder = FavoriteFolder(name: id, folderID: "default")
      folder.recordID = id
      folder.createdAt = Date(timeIntervalSince1970: 1)
      store.context.insert(folder)
    }
    try store.context.save()
    try store.reconcileDuplicates()
    XCTAssertEqual(try store.defaultFolder().recordID, "a")
  }
  func testPortraitPresentationSurvivesDetailAndPlaybackRefresh() throws {
    let store = try store()
    let portrait = LibraryMetadata(
      source: "Hanime1", mediaID: "42", title: "List",
      cover: "https://example.com/portrait", isPortrait: true)
    try store.toggleDefault(portrait)
    let landscape = LibraryMetadata(
      source: "Hanime1", mediaID: "42", title: "Detail",
      cover: "https://example.com/player-poster")
    try store.refresh(landscape)
    try store.recordVisit(landscape)
    let item = try XCTUnwrap(store.item(key: portrait.key))
    XCTAssertEqual(item.title, "Detail")
    XCTAssertEqual(item.cover, portrait.cover)
    XCTAssertTrue(item.isPortrait)
    let newList = LibraryMetadata(
      source: "Hanime1", mediaID: "42", title: "New list",
      cover: "https://example.com/new-signed-portrait", isPortrait: true)
    try store.refresh(newList)
    XCTAssertEqual(item.cover, newList.cover)
  }
  func testVideoPresentationUsesListCoverAndIwaraLetterboxing() throws {
    var detail = Video(
      id: "42", title: "Detail", author: "A", duration: nil,
      thumbnail: URL(string: "https://example.com/poster"), description: "", tags: [], fileURL: nil)
    let portrait = LibraryMetadata(
      source: "Hanime1", mediaID: "42", title: "List",
      cover: "https://example.com/portrait", isPortrait: true)
    let metadata = LibraryMetadata(video: detail, source: "Hanime1", presentation: portrait)
    XCTAssertTrue(metadata.isPortrait)
    XCTAssertEqual(metadata.cover, portrait.cover)
    XCTAssertEqual(metadata.title, "Detail")
    detail.width = 720
    detail.height = 1280
    let iwara = LibraryMetadata(video: detail, source: "iwara")
    XCTAssertFalse(iwara.isPortrait)
    XCTAssertFalse(iwara.fillCover)
    XCTAssertFalse(SavedMediaItem(iwara).metadata.fillCover)
  }
  func testUnusedItemsAreDeletedByEveryRemovalPath() throws {
    let store = try store()
    try store.toggleDefault(video)
    try store.toggleDefault(video)
    XCTAssertNil(try store.item(key: video.key))
    let folder = try store.createFolder(name: "A")
    try store.toggle(video, in: folder)
    try store.remove(try XCTUnwrap(store.item(key: video.key)), from: folder)
    XCTAssertNil(try store.item(key: video.key))
    try store.toggle(video, in: folder)
    try store.delete(folder)
    XCTAssertNil(try store.item(key: video.key))
    try store.recordVisit(video)
    try store.remove(try XCTUnwrap(store.item(key: video.key)), from: nil)
    XCTAssertNil(try store.item(key: video.key))
    try store.recordVisit(video)
    try store.clearHistory()
    XCTAssertNil(try store.item(key: video.key))
    try store.recordVisit(video)
    try store.toggleDefault(video)
    try store.toggleDefault(video)
    XCTAssertNotNil(try store.item(key: video.key), "Removing favorites must retain history")
  }
  func testPageChangesStayPendingUntilSave() throws {
    let store = try store()
    store.context.autosaveEnabled = false
    try store.recordVisit(video)
    XCTAssertFalse(store.context.hasChanges)
    try store.updateReadingPage(7, key: video.key)
    XCTAssertEqual(try store.lastPage(key: video.key), 7)
    XCTAssertTrue(store.context.hasChanges, "Page turns must not force a save")
    try store.save()
    XCTAssertFalse(store.context.hasChanges)
    let reader = ModelContext(store.container)
    XCTAssertEqual(try reader.fetch(FetchDescriptor<SavedMediaItem>()).first?.readingPage, 7)
  }

}
