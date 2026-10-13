import SwiftUI
import AVKit
import ShelfCore

private enum PlayerTestOptions {
    static var enabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        false
        #endif
    }
    static var muted: Bool { enabled && ProcessInfo.processInfo.arguments.contains("--mute-playback") }
}

struct PlayerScreen: View {
    let stream: VideoStream
    @State private var error: String?
    @State private var playbackStatus = "waiting:0"
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        SystemPlayer(url: stream.url, failed: { error = $0 }, progress: { playbackStatus = $0 })
            .ignoresSafeArea()
            .overlay(alignment: .topLeading) {
                if PlayerTestOptions.enabled {
                    // UI tests read the actual AVPlayer clock/state, not a wall-clock timer.
                    Text(playbackStatus).font(.caption.monospacedDigit())
                        .padding(12).background(.black.opacity(0.75)).padding(40)
                        .accessibilityIdentifier("player.progress")
                }
            }
            .alert("播放失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("返回详情") { dismiss() }
            } message: { Text(error ?? "") }
    }
}
struct SystemPlayer: UIViewControllerRepresentable {
    let url: URL
    let failed: (String) -> Void
    let progress: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(failed: failed, progress: progress) }
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = PlayerTestOptions.muted
        controller.player = player
        context.coordinator.observe(item, player: player)
        player.play()
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) { }
    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        controller.player?.pause()
        if let observer = coordinator.timeObserver { controller.player?.removeTimeObserver(observer) }
        coordinator.timeObserver = nil
        coordinator.observation = nil
    }
    @MainActor final class Coordinator {
        var observation: NSKeyValueObservation?
        var timeObserver: Any?
        let failed: (String) -> Void
        let progress: (String) -> Void
        init(failed: @escaping (String) -> Void, progress: @escaping (String) -> Void) {
            self.failed = failed; self.progress = progress
        }
        func observe(_ item: AVPlayerItem, player: AVPlayer) {
            observation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                if item.status == .failed {
                    let message = item.error?.localizedDescription ?? "视频无法播放"
                    Task { @MainActor [weak self] in self?.failed(message) }
                }
            }
            if PlayerTestOptions.enabled {
                timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self, weak player] time in
                    Task { @MainActor [weak self, weak player] in
                        guard let player else { return }
                        let state = player.timeControlStatus == .playing ? "playing" : "waiting"
                        self?.progress("\(state):\(String(format: "%.1f", time.seconds)):muted=\(player.isMuted)")
                    }
                }
            }
        }
    }
}
