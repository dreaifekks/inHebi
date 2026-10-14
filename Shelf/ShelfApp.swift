import ShelfCore
import SwiftUI

@MainActor @Observable final class AppModel {
  let iwara = IwaraSource()
  let wnacg = WnacgSource()
  let hanime = Hanime1Source()
  var isLoggedIn = false
  var authRevision = 0
  var ready = false
  var readerActive = false
  var startupError: String?
  private let keychain = KeychainStore()
  func restore() async {
    await iwara.setExpirationHandler { [weak self] in await self?.sessionExpired() }
    do {
      let token = try keychain.read()
      await iwara.setUserToken(token)
      isLoggedIn = token != nil
    } catch { startupError = error.localizedDescription }
    ready = true
  }
  private func sessionExpired() {
    isLoggedIn = false
    startupError = "iwara 登录已过期，当前使用游客模式，请重新登录。"
    do { try keychain.delete() } catch { startupError = error.localizedDescription }
  }
  func login(email: String, password: String) async throws {
    let token = try await iwara.login(email: email, password: password)
    do { try keychain.save(token) } catch {
      await iwara.setUserToken(nil)
      throw error
    }
    isLoggedIn = true
    startupError = nil
    authRevision += 1
  }
  func logout() async throws {
    try keychain.delete()
    await iwara.setUserToken(nil)
    isLoggedIn = false
    authRevision += 1
  }
}

@main struct ShelfApp: App {
  @State private var model = AppModel()
  init() {
    if TestMode.enabled && ProcessInfo.processInfo.arguments.contains("--ui-reset-preferences") {
      TestMode.preferences.removePersistentDomain(forName: "com.dreaife.inhebi.uitests.preferences")
    }
  }
  var body: some Scene {
    WindowGroup {
      Group {
        #if DEBUG
          if TestMode.enabled && ProcessInfo.processInfo.arguments.contains("--ui-component-probes")
          {
            UXProbeScreen()
          } else {
            content
          }
        #else
          content
        #endif
      }
      .overlay(alignment: .bottomLeading) {
        if TestMode.enabled {
          Text(
            verbatim:
              "active=\(PlaybackActivity.shared.active);stopped=\(PlaybackActivity.shared.stoppedTime)"
          ).font(.system(size: 12)).accessibilityIdentifier("playback.activity")
        }
      }
      .environment(model)
      .tint(.cyan)
      .preferredColorScheme(.dark)
      .task { if !model.ready { await model.restore() } }
    }
  }
  @ViewBuilder private var content: some View {
    if model.ready {
      TabView {
        NavigationStack { VideoBrowser(source: model.iwara, authRevision: model.authRevision) }
          .tabItem { Label("iwara", systemImage: "play.rectangle") }
        NavigationStack { VideoBrowser(source: model.hanime) }
          .tabItem { Label("Hanime1", systemImage: "film") }
        NavigationStack { AlbumBrowser(source: model.wnacg) }
          .tabItem { Label("漫画", systemImage: "books.vertical") }
        NavigationStack { SettingsView(model: model) }
          .tabItem { Label("设置", systemImage: "gearshape") }
      }
    } else {
      ProgressView("正在打开 inHebi…")
    }
  }
}
