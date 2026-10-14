import CloudKit
import CoreData
import ShelfCore
import SwiftData
import SwiftUI
import UIKit

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
  func updateReadingPage(_ page: Int, album: String) {
    libraryAction { try $0.updateReadingPage(page, key: "wnacg:" + album) }
  }
  func saveReadingPage(_ page: Int, album: String) {
    libraryAction {
      try $0.updateReadingPage(page, key: "wnacg:" + album)
      try $0.save()
    }
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
        #if DEBUG
        if completed && success && kind == "export" { model?.cloudExportCount += 1 }
        #endif
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
  private var folderIDs: Set<String> { Set(items.flatMap { ($0.folders ?? []).map(\.folderID) }) }
  private var selected: Bool { folderIDs.contains("default") }
  private var title: String { folderIDs.isEmpty ? "收藏" : "收藏 · \(folderIDs.count) 个收藏夹" }
  var body: some View {
    RemoteFavoriteButton(title: title, selected: selected,
      shortPress: { model.libraryAction { try $0.toggleDefault(metadata) } },
      longPress: {
        model.libraryAction { _ = try $0.defaultFolder() }
        choosing = true
      })
    .fixedSize()
    .sheet(isPresented: $choosing) { FolderPicker(metadata: metadata) }
  }
}

/// Native Select presses are distinct from touch gestures on the Siri Remote.
private struct RemoteFavoriteButton: UIViewRepresentable {
  let title: String
  let selected: Bool
  let shortPress: () -> Void
  let longPress: () -> Void
  func makeUIView(context: Context) -> Button { Button() }
  func updateUIView(_ button: Button, context: Context) {
    button.shortPress = shortPress
    button.longPress = longPress
    button.accessibilityLabel = title
    button.accessibilityValue = selected ? "已收藏" : "未收藏"
    button.configurationUpdateHandler = { button in
      var config = UIButton.Configuration.filled()
      config.title = title
      config.attributedTitle = AttributedString(title,
        attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 29)]))
      config.image = UIImage(systemName: selected ? "star.fill" : "star")
      config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 29)
      config.imagePadding = 12
      config.cornerStyle = .capsule
      config.contentInsets = .init(top: 12, leading: 24, bottom: 12, trailing: 24)
      config.baseBackgroundColor = button.isFocused ? .white : UIColor(white: 0.2, alpha: 1)
      config.baseForegroundColor = button.isFocused ? .black : .white
      button.configuration = config
    }
    button.setNeedsUpdateConfiguration()
  }
  func sizeThatFits(_ proposal: ProposedViewSize, uiView: Button, context: Context) -> CGSize? {
    uiView.intrinsicContentSize
  }
  final class Button: UIButton {
    var shortPress: () -> Void = {}
    var longPress: () -> Void = {}
    private var handledLongPress = false
    init() {
      super.init(frame: .zero)
      accessibilityIdentifier = "favorite.toggle"
      addTarget(self, action: #selector(selected), for: .primaryActionTriggered)
      let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
      hold.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
      hold.minimumPressDuration = 0.5
      addGestureRecognizer(hold)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      if presses.contains(where: { $0.type == .select }) { handledLongPress = false }
      super.pressesBegan(presses, with: event)
    }
    @objc private func selected() {
      if !handledLongPress {
        FocusTrace.mark("favorite short-press")
        shortPress()
      }
    }
    @objc private func held(_ gesture: UILongPressGestureRecognizer) {
      if gesture.state == .began {
        handledLongPress = true
        FocusTrace.mark("favorite long-press")
        longPress()
      }
    }
  }
}

struct FolderPicker: View {
  let metadata: LibraryMetadata
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \FavoriteFolder.createdAt) private var folders: [FavoriteFolder]
  @State private var creating = false
  @Query private var items: [SavedMediaItem]
  init(metadata: LibraryMetadata) {
    self.metadata = metadata
    let key = metadata.key
    _items = Query(filter: #Predicate<SavedMediaItem> { $0.key == key })
  }
  var body: some View {
    NavigationStack {
      List {
        ForEach(folders) { folder in
          let selected = items.contains {
            ($0.folders ?? []).contains { $0.folderID == folder.folderID }
          }
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
