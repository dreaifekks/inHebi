import SwiftUI
import AVKit
import ShelfCore

struct PlayerScreen: View {
    let stream: VideoStream
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        SystemPlayer(url: stream.url) { error = $0 }
            .ignoresSafeArea()
            .alert("播放失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("返回详情") { dismiss() }
            } message: { Text(error ?? "") }
    }
}
struct SystemPlayer: UIViewControllerRepresentable {
    let url: URL
    let failed: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(failed: failed) }
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let item = AVPlayerItem(url: url)
        context.coordinator.observe(item)
        controller.player = AVPlayer(playerItem: item)
        controller.player?.play()
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) { }
    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        controller.player?.pause(); coordinator.observation = nil
    }
    @MainActor final class Coordinator {
        var observation: NSKeyValueObservation?
        let failed: (String) -> Void
        init(failed: @escaping (String) -> Void) { self.failed = failed }
        func observe(_ item: AVPlayerItem) {
            observation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                if item.status == .failed {
                    let message = item.error?.localizedDescription ?? "视频无法播放"
                    Task { @MainActor [weak self] in self?.failed(message) }
                }
            }
        }
    }
}
