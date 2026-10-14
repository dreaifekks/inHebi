import Foundation
import SwiftData

/// Stable source + media ID identity, independent of UI and expiring media URLs.
public struct LibraryMetadata: Sendable {
  public let source: String
  public let mediaID: String
  public let title: String
  public let cover: String?
  public let subtitle: String
  public let isComic: Bool
  public let isPortrait: Bool
  public var key: String { source + ":" + mediaID }
  public init(
    source: String, mediaID: String, title: String, cover: String? = nil,
    subtitle: String = "", isComic: Bool = false, isPortrait: Bool = false
  ) {
    self.source = source
    self.mediaID = mediaID
    self.title = title
    self.cover = cover
    self.subtitle = subtitle
    self.isComic = isComic
    self.isPortrait = isPortrait
  }
  public init(video: Video, source: String) {
    self.init(
      source: source, mediaID: video.id, title: video.title,
      cover: video.thumbnail?.absoluteString, subtitle: video.author,
      isPortrait: video.isPortrait)
  }
  public init(album: Album, source: String = "wnacg") {
    self.init(
      source: source, mediaID: album.id, title: album.title,
      cover: album.cover?.absoluteString, subtitle: album.pageCount.map { "\($0)P" } ?? "",
      isComic: true, isPortrait: true)
  }
}

@Model public final class SavedMediaItem {
  public var key: String = ""
  public var source: String = ""
  public var mediaID: String = ""
  public var title: String = ""
  public var cover: String?
  public var subtitle: String = ""
  public var isComic: Bool = false
  public var isPortrait: Bool = false
  public var metadataUpdatedAt: Date = Date.distantPast
  public var lastViewedAt: Date?
  public var readingPage: Int = 0
  @Relationship(deleteRule: .nullify, inverse: \FavoriteFolder.items)
  public var folders: [FavoriteFolder]?
  public init(_ metadata: LibraryMetadata) { update(metadata) }
  public func update(_ metadata: LibraryMetadata, at date: Date = .now) {
    key = metadata.key
    source = metadata.source
    mediaID = metadata.mediaID
    title = metadata.title
    cover = metadata.cover
    subtitle = metadata.subtitle
    isComic = metadata.isComic
    isPortrait = metadata.isPortrait
    metadataUpdatedAt = date
  }
}

@Model public final class FavoriteFolder {
  /// The default folder uses a stable identity on every device.
  public var folderID: String = UUID().uuidString
  public var name: String = ""
  public var createdAt: Date = Date.now
  public var items: [SavedMediaItem]?
  public init(name: String, folderID: String = UUID().uuidString) {
    self.name = name
    self.folderID = folderID
  }
}

@MainActor public final class LibraryStore {
  public static let cloudContainer = "iCloud.com.dreaife.inhebi"
  public let container: ModelContainer
  public var context: ModelContext { container.mainContext }
  public static func makeContainer(inMemory: Bool = false, cloudSync: Bool = true) throws
    -> ModelContainer
  {
    let schema = Schema([SavedMediaItem.self, FavoriteFolder.self])
    let configuration = ModelConfiguration(
      schema: schema, isStoredInMemoryOnly: inMemory,
      cloudKitDatabase: inMemory || !cloudSync ? .none : .private(cloudContainer))
    return try ModelContainer(for: schema, configurations: [configuration])
  }
  public init(container: ModelContainer) { self.container = container }
  public func items() throws -> [SavedMediaItem] {
    try context.fetch(FetchDescriptor<SavedMediaItem>())
  }
  public func folders() throws -> [FavoriteFolder] {
    try context.fetch(
      FetchDescriptor<FavoriteFolder>(sortBy: [SortDescriptor(\FavoriteFolder.createdAt)]))
  }
  public func item(key: String) throws -> SavedMediaItem? {
    try context.fetch(FetchDescriptor<SavedMediaItem>(predicate: #Predicate { $0.key == key }))
      .first
  }
  private func upsert(_ metadata: LibraryMetadata) throws -> SavedMediaItem {
    if let item = try item(key: metadata.key) {
      item.update(metadata)
      return item
    }
    let item = SavedMediaItem(metadata)
    context.insert(item)
    return item
  }
  public func recordVisit(_ metadata: LibraryMetadata, page: Int? = nil, at date: Date = .now)
    throws
  {
    let item = try upsert(metadata)
    item.lastViewedAt = date
    if let page { item.readingPage = page }
    try context.save()
  }
  public func saveReadingPage(_ page: Int, key: String, at date: Date = .now) throws {
    if let item = try item(key: key) {
      item.readingPage = page
      item.lastViewedAt = date
      try context.save()
    }
  }
  public func lastPage(key: String) throws -> Int { try item(key: key)?.readingPage ?? 0 }
  public func refresh(_ metadata: LibraryMetadata) throws {
    if let item = try item(key: metadata.key) {
      item.update(metadata)
      try context.save()
    }
  }
  @discardableResult public func createFolder(name: String) throws -> FavoriteFolder {
    let folder = FavoriteFolder(name: name)
    context.insert(folder)
    try context.save()
    return folder
  }
  public func defaultFolder() throws -> FavoriteFolder {
    if let folder = try folders().first(where: { $0.folderID == "default" }) { return folder }
    let folder = FavoriteFolder(name: "默认收藏", folderID: "default")
    context.insert(folder)
    try context.save()
    return folder
  }
  public func rename(_ folder: FavoriteFolder, to name: String) throws {
    folder.name = name
    try context.save()
  }
  public func delete(_ folder: FavoriteFolder) throws {
    context.delete(folder)
    try context.save()
  }
  public func toggle(_ metadata: LibraryMetadata, in folder: FavoriteFolder) throws {
    let item = try upsert(metadata)
    if (item.folders ?? []).contains(where: { $0.folderID == folder.folderID }) {
      item.folders?.removeAll { $0.folderID == folder.folderID }
    } else {
      item.folders = (item.folders ?? []) + [folder]
    }
    try context.save()
  }
  public func toggleDefault(_ metadata: LibraryMetadata) throws {
    try toggle(metadata, in: defaultFolder())
  }
  public func remove(_ item: SavedMediaItem, from folder: FavoriteFolder?) throws {
    if let folder {
      item.folders?.removeAll { $0.folderID == folder.folderID }
    } else {
      item.lastViewedAt = nil
      item.readingPage = 0
    }
    try context.save()
  }
  public func clearHistory() throws {
    for item in try items() {
      item.lastViewedAt = nil
      item.readingPage = 0
    }
    try context.save()
  }
  /// CloudKit has no unique constraints. Reconcile simultaneous inserts after an import.
  public func reconcileDuplicates() throws {
    for group in Dictionary(grouping: try folders(), by: \.folderID).values where group.count > 1 {
      let kept = group.sorted { $0.createdAt < $1.createdAt }[0]
      for duplicate in group where duplicate !== kept {
        for item in duplicate.items ?? [] {
          if !(kept.items ?? []).contains(where: { $0 === item }) {
            kept.items = (kept.items ?? []) + [item]
          }
        }
        context.delete(duplicate)
      }
    }
    for group in Dictionary(grouping: try items(), by: \.key).values where group.count > 1 {
      let kept = group.sorted { $0.metadataUpdatedAt > $1.metadataUpdatedAt }[0]
      for duplicate in group where duplicate !== kept {
        if (duplicate.lastViewedAt ?? .distantPast) > (kept.lastViewedAt ?? .distantPast) {
          kept.lastViewedAt = duplicate.lastViewedAt
          kept.readingPage = duplicate.readingPage
        }
        for folder in duplicate.folders ?? [] {
          if !(kept.folders ?? []).contains(where: { $0.folderID == folder.folderID }) {
            kept.folders = (kept.folders ?? []) + [folder]
          }
        }
        context.delete(duplicate)
      }
    }
    if context.hasChanges { try context.save() }
  }
}
