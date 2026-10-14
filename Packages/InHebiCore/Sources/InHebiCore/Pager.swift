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
    private var request: Task<Page<Item>, Error>?
    public init() { }
    public func load(reset: Bool = false, key: String, first: Int, fetch: @escaping @MainActor (Int) async throws -> Page<Item>) async {
        if reset && loadedKey == key && !items.isEmpty { return }
        if loadedKey != key || (reset && items.isEmpty) {
            request?.cancel()
            generation += 1; items = []; next = first; loading = false; loadedKey = key
        }
        guard !loading, let page = next else { return }
        let current = generation
        loading = true; error = nil; requestCount += 1
        let task = Task { try await fetch(page) }
        request = task
        defer { if generation == current { loading = false; request = nil } }
        do {
            let result = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
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
