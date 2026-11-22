import AppKit
import ClipStackCore

/// Owns every component and exposes the app's actions.
@MainActor
final class AppController: ObservableObject {
    let prefs = Preferences()
    let persistence = HistoryPersistence(baseURL: HistoryPersistence.defaultBaseURL())
    let store: HistoryStore
    let thumbnails: ThumbnailCache
    let monitor = PasteboardMonitor()
    private let processor: CaptureProcessor

    @Published var isPaused = false {
        didSet { monitor.isPaused = isPaused }
    }

    init() {
        store = HistoryStore(persistence: persistence, limit: prefs.historyLimit)
        thumbnails = ThumbnailCache(persistence: persistence)
        processor = CaptureProcessor(store: store, thumbnails: thumbnails)
    }

    func start() {
        store.load()
        monitor.rulesProvider = { [unowned self] in self.prefs.captureRules }
        monitor.onCapture = { [unowned self] clip, source in self.processor.process(clip, source: source) }
        monitor.start()
    }

    func shutdown() {
        monitor.stop()
        store.flush()
    }
}
