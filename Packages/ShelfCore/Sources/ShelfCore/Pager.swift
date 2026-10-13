import Foundation
import Observation

@MainActor @Observable public final class Pager<Item: Identifiable & Sendable> where Item.ID: Sendable {
    public private(set) var items: [Item] = []
    public private(set) var next: Int?
    public private(set) var loading = false
    public private(set) var error: String?
    public private(set) var loadedKey: String?
    public private(set) var requestCount = 0
    private var generation = 0
    public init() { }
    public func load(reset: Bool = false, key: String, first: Int, fetch: (Int) async throws -> Page<Item>) async {
        if reset && loadedKey == key && !items.isEmpty { return }
        if loadedKey != key || (reset && items.isEmpty) {
            generation += 1; items = []; next = first; loading = false; loadedKey = key
        }
        guard !loading, let page = next else { return }
        let current = generation
        loading = true; error = nil; requestCount += 1
        defer { if generation == current { loading = false } }
        do {
            let result = try await fetch(page)
            try Task.checkCancellation()
            guard generation == current else { return }
            var seen = Set(items.map(\.id))
            items += result.items.filter { seen.insert($0.id).inserted }
            next = result.nextPage
        } catch is CancellationError { }
        catch let error as URLError where error.code == .cancelled { }
        catch { if generation == current { self.error = error.localizedDescription } }
    }
}
