import Combine
import Foundation

/// The clipboard history. Main-thread only (not annotated @MainActor to keep XCTest simple).
/// `items` is always sorted by `lastUsedAt`, newest first. Pinned items stay in place (Windows-style).
public final class HistoryStore: ObservableObject {
    public static let defaultLimit = 50

    @Published public private(set) var items: [ClipItem] = []
    /// Maximum number of unpinned items. Pinned items never count and are never evicted.
    public private(set) var limit: Int
    public let persistence: HistoryPersistence
    /// Injectable clock for tests.
    public var now: () -> Date = Date.init

    public init(persistence: HistoryPersistence, limit: Int = HistoryStore.defaultLimit) {
        self.persistence = persistence
        self.limit = max(1, limit)
    }

    // MARK: - Loading / saving

    public func load() {
        assertMain()
        let indexed = persistence.loadIndex()
        let kept = persistence.sweep(indexed)              // drops items whose blob is gone, deletes orphans
        items = kept.sorted { $0.lastUsedAt > $1.lastUsedAt }
        let evicted = evict()                              // evaluated separately: `||` would short-circuit it
        if evicted || kept.count != indexed.count { save() }
    }

    public func flush() {
        assertMain()
        persistence.flush(items)
    }

    // MARK: - Mutations

    /// Same content already stored → moved to the top. Otherwise inserted at the top (then eviction).
    @discardableResult
    public func insertOrBump(_ clip: ProcessedClip, sourceBundleID: String?, sourceAppName: String?) -> ClipItem {
        assertMain()
        if let index = items.firstIndex(where: { $0.contentHash == clip.contentHash && $0.kind == clip.kind }) {
            var existing = items.remove(at: index)
            existing.lastUsedAt = now()
            if let sourceBundleID { existing.sourceBundleID = sourceBundleID }
            if let sourceAppName { existing.sourceAppName = sourceAppName }
            items.insert(existing, at: 0)
            save()
            return existing
        }

        let date = now()
        let item = ClipItem(
            kind: clip.kind,
            createdAt: date,
            lastUsedAt: date,
            contentHash: clip.contentHash,
            previewText: clip.previewText,
            searchText: clip.searchText,
            charCount: clip.charCount,
            hasRTF: clip.blobs.rtf != nil,
            hasHTML: clip.blobs.html != nil,
            pixelWidth: clip.pixelWidth,
            pixelHeight: clip.pixelHeight,
            byteSize: clip.blobs.byteSize,
            sourceBundleID: sourceBundleID,
            sourceAppName: sourceAppName
        )
        persistence.writeBlobs(clip.blobs, for: item.id)
        items.insert(item, at: 0)
        evict()
        save()
        return item
    }

    /// Moves an item to the top (picked from history).
    public func bump(_ id: UUID) {
        assertMain()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: index)
        item.lastUsedAt = now()
        items.insert(item, at: 0)
        save()
    }

    /// Unpinning does not evict right away (an item shouldn't vanish the moment it's unpinned);
    /// eviction runs on the next insert or limit change.
    public func togglePin(_ id: UUID) {
        assertMain()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
        save()
    }

    public func delete(_ id: UUID) {
        assertMain()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: index)
        persistence.deleteBlobs(for: [id])
        save()
    }

    /// Removes all unpinned items (pinned ones are kept, like Windows).
    public func clearUnpinned() {
        assertMain()
        let removed = items.filter { !$0.isPinned }.map(\.id)
        items.removeAll { !$0.isPinned }
        persistence.deleteBlobs(for: removed)
        save()
    }

    public func clearAll() {
        assertMain()
        let removed = items.map(\.id)
        items.removeAll()
        persistence.deleteBlobs(for: removed)
        save()
    }

    public func setLimit(_ newLimit: Int) {
        assertMain()
        limit = max(1, newLimit)
        if evict() { save() }
    }

    // MARK: - Queries

    /// How many items a new limit would delete (for the confirmation alert).
    public func evictionCount(forLimit newLimit: Int) -> Int {
        max(0, unpinnedCount - max(1, newLimit))
    }

    public var unpinnedCount: Int { items.lazy.filter { !$0.isPinned }.count }
    public var pinnedCount: Int { items.lazy.filter(\.isPinned).count }
    public var totalBytes: Int { items.reduce(0) { $0 + $1.byteSize } }

    public func item(withID id: UUID) -> ClipItem? { items.first { $0.id == id } }

    // MARK: - Private

    /// Keeps the newest `limit` unpinned items. Returns true when something was removed.
    @discardableResult
    private func evict() -> Bool {
        let unpinned = items.filter { !$0.isPinned }       // already newest first
        guard unpinned.count > limit else { return false }
        let victims = Set(unpinned.dropFirst(limit).map(\.id))
        items.removeAll { victims.contains($0.id) }
        persistence.deleteBlobs(for: Array(victims))
        return true
    }

    private func save() {
        persistence.scheduleSave(items)
    }

    private func assertMain() {
        dispatchPrecondition(condition: .onQueue(.main))
    }
}
