import InHebiCore
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
  @State private var managing: FolderRoute?
  @State private var detailRoute: LibraryRoute?
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
            if selection == "history" {
              confirmingClear = true
            } else if let folder {
              managing = FolderRoute(id: folder.folderID, name: folder.name)
            }
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
                      width: geometry.size.width - 2 * InHebiLayout.horizontalInset,
                      portrait: portrait, comic: source == "wnacg", materializesAllRows: true,
                      referer: source == "wnacg" ? model.wnacg.imageReferer(albumID: nil) : nil,
                      focus: $controlFocus, preparing: preparing, quickError: quickError,
                      failedID: failedID,
                      remove: { key in
                        if let item = entries.first(where: { $0.key == key }) {
                          model.libraryAction { try $0.remove(item, from: folder) }
                        }
                      },
                      openDetail: { key in
                        if let item = entries.first(where: { $0.key == key }) {
                          detailRoute = LibraryRoute(metadata: item.metadata)
                        }
                      },
                      destination: { _ in EmptyView() },
                      quick: { key in
                        if let item = entries.first(where: { $0.key == key }) {
                          Task { await open(item.metadata, page: item.readingPage) }
                        }
                      })
                  }
                }
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, InHebiLayout.horizontalInset).padding(.vertical, 30)
          .focusSection()
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
        if selection != "history" && !ids.contains(selection) {
          selection = "history"
          focus = .chip("history")
          if managing == nil { controlFocus = .strip }
        }
        if let managing, !ids.contains(managing.id) { self.managing = nil }
      }
    }
    .ignoresSafeArea(.container, edges: .horizontal)
    .toolbarVisibility(model.readerActive ? .hidden : .visible, for: .tabBar)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("library.screen")
    .onAppear {
      model.traceLibrary(stage: "library-appeared")
      FocusTrace.mark("library query total=\(items.count) visible=\(visibleItems.count) comics=\(visibleItems.filter(\.isComic).count) sources=\(Set(visibleItems.map(\.source)).sorted())")
    }
    .fullScreenCover(item: $playback) { PlayerScreen(playback: $0) }
    .navigationDestination(item: $reading) { ReaderView(session: $0) }
    .navigationDestination(item: $detailRoute) { detail($0.metadata) }
    .sheet(
      item: $managing,
      onDismiss: {
        if selection == "history" {
          controlFocus = nil
          Task { @MainActor in
            await Task.yield()
            controlFocus = .strip
          }
        }
      }
    ) { route in
      FolderManager(folderID: route.id, name: route.name)
    }
    .confirmationDialog("清空观看历史？", isPresented: $confirmingClear) {
      Button("清空历史", role: .destructive) { model.libraryAction { try $0.clearHistory() } }
    }
  }
  @ViewBuilder private func detail(_ item: LibraryMetadata) -> some View {
    if item.isComic {
      AlbumDetail(source: model.wnacg, id: item.mediaID)
    } else {
      VideoDetail(source: videoSource(item.source), id: item.mediaID, cardMetadata: item)
    }
  }
  private func videoSource(_ name: String) -> any VideoSource {
    name == "iwara" ? model.iwara : model.hanime
  }
  private func open(_ item: LibraryMetadata, page: Int) async {
    guard preparing == nil else { return }
    preparing = item.key
    quickError = nil
    failedID = nil
    defer { preparing = nil }
    do {
      if item.isComic {
        let pages = try await model.wnacg.pages(id: item.mediaID)
        try model.library.recordVisit(item)
        model.traceLibrary(stage: "comic-library-saved")
        reading = ReadingSession(
          pages: pages, albumID: item.mediaID,
          referer: model.wnacg.imageReferer(albumID: item.mediaID), startPage: page)
      } else {
        let source = videoSource(item.source)
        let video = try await source.video(id: item.mediaID)
        guard let stream = try await source.streams(for: video).first else {
          throw InHebiError.message("没有可播放的清晰度")
        }
        playback = VideoPlayback(
          video: video, stream: stream, sourceName: source.name, cardMetadata: item)
      }
    } catch {
      quickError = error.localizedDescription
      failedID = item.key
    }
  }
}

private struct LibraryRoute: Hashable, Identifiable {
  let metadata: LibraryMetadata
  var id: String { metadata.key }
}
private struct FolderRoute: Identifiable {
  let id: String
  let name: String
}

struct FolderManager: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @Query private var folders: [FavoriteFolder]
  @State private var name: String
  @State private var renaming = false
  @State private var deleting = false
  init(folderID: String, name: String) {
    _name = State(initialValue: name)
    _folders = Query(filter: #Predicate<FavoriteFolder> { $0.folderID == folderID })
  }
  var body: some View {
    NavigationStack {
      List {
        Button("重命名") { renaming = true }.accessibilityIdentifier("folder.rename")
        Button("删除收藏夹", role: .destructive) { deleting = true }.accessibilityIdentifier(
          "folder.delete")
        Button("完成") { dismiss() }.accessibilityIdentifier("folder.manager.done")
      }.navigationTitle(name)
    }
    .sheet(isPresented: $renaming) {
      FolderEditor(initialName: name) { newName in
        if let folder = folders.first {
          model.libraryAction { try $0.rename(folder, to: newName) }
          name = newName
        }
      }
    }
    .onChange(of: folders.isEmpty) { _, empty in if empty { dismiss() } }
    .confirmationDialog("删除收藏夹？历史记录会保留。", isPresented: $deleting) {
      Button("删除收藏夹", role: .destructive) {
        dismiss()
        if let folder = folders.first { model.libraryAction { try $0.delete(folder) } }
      }.accessibilityIdentifier("folder.delete.confirm")
    }
  }
}
