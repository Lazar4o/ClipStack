import AppKit
import ClipStackCore

/// In-memory thumbnails for list rows. Fresh captures are inserted directly;
/// older ones are read from disk on a background queue. Full-size images are never decoded here.
@MainActor
final class ThumbnailCache {
    private let cache = NSCache<NSString, NSImage>()
    private let persistence: HistoryPersistence
    private let queue = DispatchQueue(label: "local.tools.ClipStack.thumbnails", qos: .userInitiated)

    init(persistence: HistoryPersistence) {
        self.persistence = persistence
        cache.countLimit = 300
    }

    func cached(_ id: UUID) -> NSImage? {
        cache.object(forKey: id.uuidString as NSString)
    }

    func insert(_ pngData: Data, for id: UUID) {
        guard let image = NSImage(data: pngData) else { return }
        cache.setObject(image, forKey: id.uuidString as NSString)
    }

    func load(_ id: UUID) async -> NSImage? {
        if let image = cached(id) { return image }
        let persistence = self.persistence
        let data: Data? = await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: persistence.loadThumbnail(id)) }
        }
        guard let data, let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: id.uuidString as NSString)
        return image
    }
}
