import CloudKit
import CoreData
import ShelfCore
import SwiftData
import SwiftUI

extension AppModel {
  func libraryAction(_ action: (LibraryStore) throws -> Void) {
    do { try action(library) } catch { libraryError = error.localizedDescription }
  }
  func lastReadingPage(_ album: String) -> Int {
    do { return try library.lastPage(key: "wnacg:" + album) } catch {
      libraryError = error.localizedDescription
      return 0
    }
  }
  func saveReadingPage(_ page: Int, album: String) {
    libraryAction { try $0.saveReadingPage(page, key: "wnacg:" + album) }
  }
  func refreshCloudAccount() async {
    do {
      let status = try await CKContainer(identifier: LibraryStore.cloudContainer).accountStatus()
      cloudAccountStatus = status == .available ? "已登录 iCloud" : "未登录 iCloud"
    } catch { cloudAccountStatus = "iCloud 状态暂不可用" }
  }
}

/// Observe the backing CloudKit store's completed imports/exports without logging record content.
@MainActor final class CloudSyncMonitor {
  private var observer: NSObjectProtocol?
  init(model: AppModel) {
    observer = NotificationCenter.default.addObserver(
      forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
    ) { [weak model] notification in
      guard
        let event = notification.userInfo?[
          NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
          as? NSPersistentCloudKitContainer.Event
      else { return }
      let completed = event.endDate != nil
      let imported = event.type == .import
      let kind = event.type == .export ? "export" : (imported ? "import" : "setup")
      let success = event.succeeded
      let error =
        event.error.map { ($0 as NSError).domain + ":" + String(($0 as NSError).code) } ?? "none"
      Task { @MainActor in
        FocusTrace.mark(
          "cloudkit kind=\(kind) completed=\(completed) success=\(success) error=\(error)")
        if completed && success && imported {
          model?.libraryAction { try $0.reconcileDuplicates() }
        }
      }
    }
  }
}

struct FavoriteButton: View {
  let metadata: LibraryMetadata
  @Environment(AppModel.self) private var model
  @Query private var items: [SavedMediaItem]
  @State private var choosing = false
  init(metadata: LibraryMetadata) {
    self.metadata = metadata
    let key = metadata.key
    _items = Query(filter: #Predicate<SavedMediaItem> { $0.key == key })
  }
  private var selected: Bool { items.contains { !($0.folders ?? []).isEmpty } }
  var body: some View {
    Button {
      model.libraryAction { try $0.toggleDefault(metadata) }
    } label: {
      Image(systemName: selected ? "star.fill" : "star")
    }
    .accessibilityLabel("收藏")
    .accessibilityValue(selected ? "已收藏" : "未收藏")
    .accessibilityIdentifier("favorite.toggle")
    .onLongPressGesture {
      model.libraryAction { _ = try $0.defaultFolder() }
      choosing = true
    }
    .sheet(isPresented: $choosing) { FolderPicker(metadata: metadata) }
  }
}

struct FolderPicker: View {
  let metadata: LibraryMetadata
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \FavoriteFolder.createdAt) private var folders: [FavoriteFolder]
  @State private var creating = false
  var body: some View {
    NavigationStack {
      List {
        ForEach(folders) { folder in
          let selected = (folder.items ?? []).contains { $0.key == metadata.key }
          Button {
            model.libraryAction { try $0.toggle(metadata, in: folder) }
          } label: {
            HStack {
              Text(folder.name)
              Spacer()
              Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            }
          }.accessibilityIdentifier("favorite.folder.\(folder.folderID)")
            .accessibilityValue(selected ? "已加入" : "未加入")
        }
        Button("新建收藏夹") { creating = true }.accessibilityIdentifier("folder.create")
        Button("完成") { dismiss() }.accessibilityIdentifier("folder.done")
      }.navigationTitle("选择收藏夹")
    }
    .sheet(isPresented: $creating) {
      FolderEditor { name in
        model.libraryAction { store in
          let folder = try store.createFolder(name: name)
          try store.toggle(metadata, in: folder)
        }
      }
    }
  }
}

struct FolderEditor: View {
  var initialName = ""
  let save: (String) -> Void
  @State private var name = ""
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      VStack(spacing: 32) {
        TextField("收藏夹名称", text: $name).accessibilityIdentifier("folder.name")
        Button("保存") {
          save(name.trimmingCharacters(in: .whitespacesAndNewlines))
          dismiss()
        }
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityIdentifier("folder.save")
        Button("取消") { dismiss() }
      }.padding(100).navigationTitle(initialName.isEmpty ? "新建收藏夹" : "重命名收藏夹")
    }.onAppear { name = initialName }
  }
}
