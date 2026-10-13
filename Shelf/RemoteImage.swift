import SwiftUI
import ShelfCore
import ImageIO

@MainActor final class ImageStore {
    static let shared = ImageStore()
    private let cache = NSCache<NSURL, UIImage>()
    private var pending: [URL: Task<UIImage, Error>] = [:]
    private let http: HTTPClient
    private init() {
        cache.totalCostLimit = 100 * 1024 * 1024
        let configuration = URLSessionConfiguration.ephemeral
        http = HTTPClient(session: URLSession(configuration: configuration))
    }
    func image(_ url: URL, referer: String?) async throws -> UIImage {
        if let image = cache.object(forKey: url as NSURL) { return image }
        if let task = pending[url] { return try await task.value }
        let http = http
        let task = Task.detached { () throws -> UIImage in
            let data = try await http.data(url, headers: referer.map { ["Referer": $0] } ?? [:])
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 2400, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { throw ShelfError.parse("图片") }
            return UIImage(cgImage: cgImage)
        }
        pending[url] = task
        defer { pending[url] = nil }
        let image = try await task.value
        cache.setObject(image, forKey: url as NSURL, cost: (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0))
        return image
    }
}

struct RemoteImage: View {
    let url: URL?
    var referer: String?
    @State private var image: UIImage?
    @State private var error: String?
    var body: some View {
        ZStack {
            Color.white.opacity(0.04)
            if let image { Image(uiImage: image).resizable().scaledToFit().accessibilityIdentifier("image.loaded") }
            else if let error { VStack { Image(systemName: "photo.badge.exclamationmark"); Text(error).font(.caption).lineLimit(2) } }
            else if url != nil { ProgressView() }
            else { Image(systemName: "photo").foregroundStyle(.secondary) }
        }
        .task(id: url) {
            image = nil; error = nil
            guard let url else { return }
            do {
                let loaded = try await ImageStore.shared.image(url, referer: referer)
                try Task.checkCancellation()
                image = loaded
            } catch is CancellationError { }
            catch { self.error = error.localizedDescription }
        }
    }
}
