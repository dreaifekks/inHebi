import ImageIO
import InHebiCore
import SwiftUI

@MainActor final class ImageStore {
  static let shared = ImageStore()
  private let cache = NSCache<NSString, UIImage>()
  private let http: HTTPClient
  private init() {
    cache.totalCostLimit = 100 * 1024 * 1024
    http = HTTPClient(session: URLSession(configuration: .ephemeral))
  }
  func image(_ url: URL, referer: String?, maxPixelSize: Int = 2400) async throws -> UIImage {
    let key = "\(maxPixelSize)|\(url.absoluteString)" as NSString
    if let image = cache.object(forKey: key) { return image }
    // The caller's .task owns the request; cancellation reaches URLSession directly.
    let data = try await http.data(url, headers: referer.map { ["Referer": $0] } ?? [:])
    try Task.checkCancellation()
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let cgImage = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
          kCGImageSourceCreateThumbnailWithTransform: true,
        ] as CFDictionary)
    else { throw InHebiError.parse("图片") }
    let image = UIImage(cgImage: cgImage)
    cache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
    return image
  }
}

struct RemoteImage: View {
  let url: URL?
  var referer: String?
  var maxPixelSize = 1600
  var fill = false
  var onLoadStateChange: ((Bool) -> Void)?
  var onImageSizeChange: ((CGSize) -> Void)?
  @State private var image: UIImage?
  @State private var error: String?
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color(white: 0.08)
        if let image {
          Image(uiImage: image).resizable().aspectRatio(contentMode: fill ? .fill : .fit)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .accessibilityIdentifier("image.loaded")
        } else if let error {
          VStack {
            Image(systemName: "photo.badge.exclamationmark")
            Text(error).font(.caption).lineLimit(2)
          }
        } else if url != nil {
          ProgressView()
        } else {
          Image(systemName: "photo").foregroundStyle(.secondary)
        }
      }.clipped()
    }
    .task(id: "\(url?.absoluteString ?? "")|\(maxPixelSize)") {
      image = nil
      error = nil
      onLoadStateChange?(false)
      guard let url else { return }
      do {
        let loaded = try await ImageStore.shared.image(
          url, referer: referer, maxPixelSize: maxPixelSize)
        image = loaded
        onImageSizeChange?(loaded.size)
        onLoadStateChange?(true)
      } catch is CancellationError {} catch let error as URLError where error.code == .cancelled {
      } catch { self.error = error.localizedDescription }
    }
  }
}
