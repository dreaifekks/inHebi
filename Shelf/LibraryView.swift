import ShelfCore
import SwiftData
import SwiftUI

struct LibraryView: View {
  @Environment(AppModel.self) private var model
  @Query(sort: \SavedMediaItem.lastViewedAt, order: .reverse) private var items: [SavedMediaItem]
  @Query(sort: \FavoriteFolder.createdAt) private var folders: [FavoriteFolder]
  @State private var selection = "history"
  @State private var focus: BrowseFocus?
  @FocusState private var controlFocus: BrowseFocus?
  @State private var position = ScrollPosition(idType: String.self)
  @State private var managing = false
  @State private var confirmingClear = false
  @State private var playback: VideoPlayback?
  @State private var reading: ReadingSession?
  @State private var preparing: String?
  @State private var quickError: String?
  @State private var failedID: String?
  private var folder: FavoriteFolder? { folders.first { $0.folderID == selection } }
  private var visibleItems: [SavedMediaItem] {
    if selection == "history" { return items.filter { $0.lastViewedAt != nil } }
    return items.filter { item in (item.folders ?? []).contains { $0.folderID == selection } }
  }
  private var gridFocused: Bool { if case .card = focus { true } else { false } }
  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        FilterBar(
          options: [SourceOption("history", "历史")]
            + folders.map { SourceOption($0.folderID, $0.name) },
          selection: $selection, focus: $focus, controlFocus: $controlFocus,
          filterTitle: selection == "history" ? "清空历史" : "管理收藏夹",
          filterAction: {
            if selection == "history" { confirmingClear = true } else { managing = true }
          },
          search: AnyView(EmptyView()))
        ScrollView {
          VStack(alignment: .leading, spacing: 30) {
            if visibleItems.isEmpty {
              ContentUnavailableView(
                selection == "history" ? "还没有观看历史" : "收藏夹为空", systemImage: "star"
              )
              .frame(maxWidth: .infinity, minHeight: 450)
            }
            ForEach(["iwara", "Hanime1", "wnacg"], id: \.self) { source in
              let section = visibleItems.filter { $0.source == source }
              if !section.isEmpty {
                Text(source == "wnacg" ? "漫画" : source).font(.title2)
                // A source can contain both orientations; keep each card's native aspect ratio.
                ForEach([false, true], id: \.self) { portrait in
                  let entries = section.filter { $0.isPortrait == portrait }
                  if !entries.isEmpty {
                    MediaGrid(
                      entries: entries.map(MediaEntry.init),
                      width: geometry.size.width - 2 * ShelfLayout.horizontalInset,
                      portrait: portrait, comic: source == "wnacg",
                      referer: source == "wnacg" ? model.wnacg.imageReferer(albumID: nil) : nil,
                      focus: $controlFocus, preparing: preparing, quickError: quickError,
                      failedID: failedID,
                      remove: { key in
                        if let item = entries.first(where: { $0.key == key }) {
                          model.libraryAction { try $0.remove(item, from: folder) }
                        }
                      },
                      destination: { key in detail(entries.first { $0.key == key }!) },
                      quick: { key in
                        if let item = entries.first(where: { $0.key == key }) {
                          Task { await open(item) }
                        }
                      })
                  }
                }
              }
            }
          }.padding(.horizontal, ShelfLayout.horizontalInset).padding(.vertical, 30)
        }
        .scrollPosition($position)
        .onExitCommand(
          perform: gridFocused
            ? {
              position.scrollTo(y: 0)
              controlFocus = .strip
            } : nil)
      }
      .onChange(of: controlFocus) { old, new in
        if new == .strip { return }
        if let new { focus = new } else if focus == old { focus = nil }
      }
      .onChange(of: selection) { _, _ in position.scrollTo(y: 0) }
      .onChange(of: folders.map(\.folderID)) { _, ids in
        if selection != "history" && !ids.contains(selection) { selection = "history" }
      }
    }
    .ignoresSafeArea(.container, edges: .horizontal)
    .toolbarVisibility(model.readerActive ? .hidden : .visible, for: .tabBar)
    .accessibilityIdentifier("library.screen")
    .fullScreenCover(item: $playback) { PlayerScreen(playback: $0) }
    .navigationDestination(item: $reading) { ReaderView(session: $0) }
    .sheet(isPresented: $managing) {
      if let folder { FolderManager(folder: folder) }
    }
    .confirmationDialog("清空观看历史？", isPresented: $confirmingClear) {
      Button("清空历史", role: .destructive) { model.libraryAction { try $0.clearHistory() } }
    }
  }
  @ViewBuilder private func detail(_ item: SavedMediaItem) -> some View {
    if item.isComic {
      AlbumDetail(source: model.wnacg, id: item.mediaID)
    } else {
      VideoDetail(source: videoSource(item.source), id: item.mediaID)
    }
  }
  private func videoSource(_ name: String) -> any VideoSource {
    name == "iwara" ? model.iwara : model.hanime
  }
  private func open(_ item: SavedMediaItem) async {
    guard preparing == nil else { return }
    preparing = item.key
    quickError = nil
    failedID = nil
    defer { preparing = nil }
    do {
      if item.isComic {
        let album = try await model.wnacg.album(id: item.mediaID)
        let pages = try await model.wnacg.pages(id: item.mediaID)
        try model.library.recordVisit(LibraryMetadata(album: album))
        reading = ReadingSession(
          pages: pages, albumID: item.mediaID,
          referer: model.wnacg.imageReferer(albumID: item.mediaID), startPage: item.readingPage)
      } else {
        let source = videoSource(item.source)
        let video = try await source.video(id: item.mediaID)
        guard let stream = try await source.streams(for: video).first else {
          throw ShelfError.message("没有可播放的清晰度")
        }
        playback = VideoPlayback(video: video, stream: stream, sourceName: source.name)
      }
    } catch {
      quickError = error.localizedDescription
      failedID = item.key
    }
  }
}

struct FolderManager: View {
  let folder: FavoriteFolder
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var renaming = false
  @State private var deleting = false
  var body: some View {
    NavigationStack {
      List {
        Button("重命名") { renaming = true }.accessibilityIdentifier("folder.rename")
        Button("删除收藏夹", role: .destructive) { deleting = true }.accessibilityIdentifier(
          "folder.delete")
        Button("完成") { dismiss() }
      }.navigationTitle(folder.name)
    }
    .sheet(isPresented: $renaming) {
      FolderEditor(initialName: folder.name) { name in
        model.libraryAction { try $0.rename(folder, to: name) }
      }
    }
    .confirmationDialog("删除收藏夹？历史记录会保留。", isPresented: $deleting) {
      Button("删除收藏夹", role: .destructive) {
        model.libraryAction { try $0.delete(folder) }
        dismiss()
      }
    }
  }
}
