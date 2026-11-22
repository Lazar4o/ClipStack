import AppKit
import ClipStackCore

/// Hashing / PNG normalizing / thumbnails run on a background serial queue (keeps capture order);
/// the result is inserted into the store on the main thread.
@MainActor
final class CaptureProcessor {
    private let store: HistoryStore
    private let thumbnails: ThumbnailCache
    private let queue = DispatchQueue(label: "local.tools.ClipStack.capture", qos: .userInitiated)

    init(store: HistoryStore, thumbnails: ThumbnailCache) {
        self.store = store
        self.thumbnails = thumbnails
    }

    func process(_ clip: CapturedClip, source: SourceApp) {
        queue.async { [weak self] in
            guard let processed = ClipProcessing.process(clip) else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let item = self.store.insertOrBump(processed, sourceBundleID: source.bundleID,
                                                       sourceAppName: source.name)
                    if let thumbnail = processed.blobs.thumbnail {
                        self.thumbnails.insert(thumbnail, for: item.id)
                    }
                }
            }
        }
    }
}
