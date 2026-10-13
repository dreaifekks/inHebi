import SwiftUI

struct SettingsView: View {
    let model: AppModel
    @State private var email = ""
    @State private var password = ""
    @State private var working = false
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Shelf 设置").font(.largeTitle.bold())
                Text("iwara 账号").font(.title2)
                if model.isLoggedIn {
                    Label("已登录 · 凭证保存在本机钥匙串", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    Button("退出登录") { Task { await logout() } }.disabled(working)
                } else {
                    Text("登录后使用账号可访问的内容；凭证仅保存在本机钥匙串。").foregroundStyle(.secondary)
                    TextField("邮箱", text: $email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("密码", text: $password).textContentType(.password).onSubmit { Task { await login() } }
                    Button(working ? "登录中…" : "登录") { Task { await login() } }.disabled(working || email.isEmpty || password.isEmpty)
                }
                if working { ProgressView() }
                if let error = error ?? model.startupError { Text(error).foregroundStyle(.orange) }
                Divider()
                Text("漫画阅读").font(.title2)
                Text("左右键翻页；向左为下一页，向右为上一页。按选择键或播放/暂停键打开阅读选项，切换单页或双页。双页右侧为前一页。").foregroundStyle(.secondary)
                Text("Shelf 1.0 · 仅本机使用").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: 1000, alignment: .leading).padding(70).frame(maxWidth: .infinity)
        }
        .onDisappear { password = "" }
    }
    private func login() async {
        guard !working else { return }
        working = true; error = nil
        defer { working = false; password = "" }
        do { try await model.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password) }
        catch { self.error = error.localizedDescription }
    }
    private func logout() async {
        working = true; error = nil
        defer { working = false }
        do { try await model.logout() }
        catch { self.error = error.localizedDescription }
    }
}
