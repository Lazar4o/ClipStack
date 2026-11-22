import AppKit
import ClipStackCore

/// UserDefaults-backed settings. Side effects (re-registering the hotkey, evicting) are done
/// explicitly by AppController, not via Combine sinks.
@MainActor
final class Preferences: ObservableObject {
    enum PasteMode: String, CaseIterable { case autoPaste, copyOnly }
    enum PanelPosition: String, CaseIterable { case mouse, center }

    static let limitOptions = [10, 20, 50, 100]

    private enum Key {
        static let historyLimit = "historyLimit"
        static let shortcut = "shortcut"
        static let pasteMode = "pasteMode"
        static let panelPosition = "panelPosition"
        static let captureText = "captureText"
        static let captureImages = "captureImages"
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }

    private let defaults: UserDefaults

    @Published var historyLimit: Int {
        didSet { defaults.set(historyLimit, forKey: Key.historyLimit) }
    }
    @Published var shortcut: Shortcut {
        didSet {
            if let data = try? JSONEncoder().encode(shortcut) { defaults.set(data, forKey: Key.shortcut) }
        }
    }
    @Published var pasteMode: PasteMode {
        didSet { defaults.set(pasteMode.rawValue, forKey: Key.pasteMode) }
    }
    @Published var panelPosition: PanelPosition {
        didSet { defaults.set(panelPosition.rawValue, forKey: Key.panelPosition) }
    }
    @Published var captureText: Bool {
        didSet { defaults.set(captureText, forKey: Key.captureText) }
    }
    @Published var captureImages: Bool {
        didSet { defaults.set(captureImages, forKey: Key.captureImages) }
    }

    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Key.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Key.hasLaunchedBefore) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.historyLimit: HistoryStore.defaultLimit,
            Key.pasteMode: PasteMode.autoPaste.rawValue,
            Key.panelPosition: PanelPosition.mouse.rawValue,
            Key.captureText: true,
            Key.captureImages: true,
        ])
        let limit = defaults.integer(forKey: Key.historyLimit)
        historyLimit = Self.limitOptions.contains(limit) ? limit : HistoryStore.defaultLimit
        shortcut = defaults.data(forKey: Key.shortcut).flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
            ?? .defaultShortcut
        pasteMode = PasteMode(rawValue: defaults.string(forKey: Key.pasteMode) ?? "") ?? .autoPaste
        panelPosition = PanelPosition(rawValue: defaults.string(forKey: Key.panelPosition) ?? "") ?? .mouse
        captureText = defaults.bool(forKey: Key.captureText)
        captureImages = defaults.bool(forKey: Key.captureImages)
    }

    var captureRules: CaptureRules {
        CaptureRules(captureText: captureText, captureImages: captureImages)
    }
}
