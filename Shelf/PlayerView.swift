import AVKit
import ShelfCore
import SwiftUI

struct VideoPlayback: Identifiable {
  let id = UUID()
  let video: Video
  let stream: VideoStream
  let sourceName: String
}
struct PlayerScreen: View {
  @Environment(AppModel.self) private var model
  let playback: VideoPlayback
  @State private var error: String?
  @State private var playbackStatus = "waiting:0"
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    SystemPlayer(
      playback: playback, failed: { error = $0 }, progress: { playbackStatus = $0 },
      finished: { dismiss() }
    )
    .ignoresSafeArea()
    .overlay(alignment: .topLeading) {
      if TestMode.enabled {
        Text(playbackStatus).font(.caption.monospacedDigit()).padding(12).background(
          .black.opacity(0.75)
        ).padding(40)
          .accessibilityIdentifier("player.progress")
      }
    }
    .onAppear {
      model.libraryAction { try $0.recordVisit(LibraryMetadata(video: playback.video, source: playback.sourceName)) }
    }
    .onExitCommand { dismiss() }
    .alert("播放失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
      Button("返回详情") { dismiss() }
    } message: {
      Text(error ?? "")
    }
  }
}
struct SystemPlayer: UIViewControllerRepresentable {
  let playback: VideoPlayback
  let failed: (String) -> Void
  let progress: (String) -> Void
  let finished: () -> Void
  func makeCoordinator() -> Coordinator {
    Coordinator(failed: failed, progress: progress, finished: finished)
  }
  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()
    let item = AVPlayerItem(url: playback.stream.url)
    let player = AVPlayer(playerItem: item)
    player.isMuted =
      TestMode.enabled && ProcessInfo.processInfo.arguments.contains("--mute-playback")
    controller.player = player
    controller.delegate = context.coordinator
    context.coordinator.observe(item, player: player, video: playback.video)
    PlaybackActivity.shared.active = true
    player.play()
    return controller
  }
  func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}
  static func dismantleUIViewController(
    _ controller: AVPlayerViewController, coordinator: Coordinator
  ) {
    controller.player?.pause()
    PlaybackActivity.shared.stoppedTime = controller.player?.currentTime().seconds ?? 0
    PlaybackActivity.shared.active = false
    if let observer = coordinator.timeObserver { controller.player?.removeTimeObserver(observer) }
    if let observer = coordinator.endObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    coordinator.artworkTask?.cancel()
    coordinator.timeObserver = nil
    coordinator.endObserver = nil
    coordinator.observation = nil
    controller.player?.replaceCurrentItem(with: nil)
  }
  @MainActor final class Coordinator: NSObject, @preconcurrency AVPlayerViewControllerDelegate {
    var observation: NSKeyValueObservation?
    var timeObserver: Any?
    var endObserver: NSObjectProtocol?
    var artworkTask: Task<Void, Never>?
    var seekingToEnd = false
    let failed: (String) -> Void
    let progress: (String) -> Void
    let finished: () -> Void
    init(
      failed: @escaping (String) -> Void, progress: @escaping (String) -> Void,
      finished: @escaping () -> Void
    ) {
      self.failed = failed
      self.progress = progress
      self.finished = finished
      super.init()
    }
    func playerViewControllerShouldDismiss(_ playerViewController: AVPlayerViewController) -> Bool {
      playerViewController.player?.pause()
      finished()
      return false  // SwiftUI owns the surrounding presentation.
    }
    private func metadata(_ id: AVMetadataIdentifier, value: any NSCopying & NSObjectProtocol)
      -> AVMetadataItem
    {
      let item = AVMutableMetadataItem()
      item.identifier = id
      item.value = value
      item.extendedLanguageTag = "und"
      return item
    }
    func observe(_ item: AVPlayerItem, player: AVPlayer, video: Video) {
      item.externalMetadata = [
        metadata(.commonIdentifierTitle, value: video.title as NSString),
        metadata(.commonIdentifierArtist, value: video.author as NSString),
        metadata(.commonIdentifierDescription, value: "作者：\(video.author)" as NSString),
      ]
      artworkTask = Task { [weak self, weak item] in
        guard let url = video.thumbnail else { return }
        do {
          let image = try await ImageStore.shared.image(
            url, referer: nil, maxPixelSize: ShelfLayout.detailPixels)
          try Task.checkCancellation()
          if let data = image.jpegData(compressionQuality: 0.85), let self, let item {
            item.externalMetadata.append(
              self.metadata(.commonIdentifierArtwork, value: data as NSData))
          }
        } catch { /* Artwork is optional; playback remains available. */  }
      }
      observation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
        if item.status == .failed {
          let message = item.error?.localizedDescription ?? "视频无法播放"
          Task { @MainActor [weak self] in self?.failed(message) }
        }
      }
      endObserver = NotificationCenter.default.addObserver(
        forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in self?.finished() }
      }
      if TestMode.enabled {
        timeObserver = player.addPeriodicTimeObserver(
          forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
        ) { [weak self, weak player] time in
          Task { @MainActor [weak self, weak player] in
            guard let self, let player else { return }
            let state = player.timeControlStatus == .playing ? "playing" : "waiting"
            self.progress(
              "\(state):\(String(format: "%.1f", time.seconds)):muted=\(player.isMuted)")
            if ProcessInfo.processInfo.arguments.contains("--ui-test-playback-end"),
              !self.seekingToEnd, time.seconds >= 1,
              let duration = player.currentItem?.duration.seconds, duration.isFinite
            {
              self.seekingToEnd = true
              await player.seek(to: CMTime(seconds: max(0, duration - 1), preferredTimescale: 600))
            }
          }
        }
      }
    }
  }
}
