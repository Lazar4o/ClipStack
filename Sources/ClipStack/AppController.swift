import AppKit
import ClipStackCore
import os

/// Owns every component and exposes the app's actions.
@MainActor
final class AppController: ObservableObject {
    let prefs = Preferences()
    let persistence = HistoryPersistence(baseURL: HistoryPersistence.defaultBaseURL())
    let store: HistoryStore
    let thumbnails: ThumbnailCache
    let monitor = PasteboardMonitor()
    private let processor: CaptureProcessor
    private lazy var pasteService = PasteService(store: store, monitor: monitor)
    private lazy var panelController: PanelController = {
        let panel = PanelController(store: store, prefs: prefs, thumbnails: thumbnails, pasteService: pasteService)
        panel.onOpenSettings = { [weak self] in self?.openSettings() }
        return panel
    }()
    private lazy var settingsController = SettingsWindowController(controller: self)
    private var statusItemController: StatusItemController?
    private let log = Logger(subsystem: "local.tools.ClipStack", category: "app")

    @Published private(set) var isPaused = false
    @Published var shortcutError: String?
    @Published private(set) var accessibilityGranted = Permissions.accessibilityGranted
    @Published private(set) var clipboardAccess = Permissions.clipboardAccess
    @Published private(set) var loginEnabled = LaunchAtLogin.isEnabled
    @Published private(set) var loginNeedsApproval = LaunchAtLogin.needsApproval

    init() {
        store = HistoryStore(persistence: persistence, limit: prefs.historyLimit)
        thumbnails = ThumbnailCache(persistence: persistence)
        processor = CaptureProcessor(store: store, thumbnails: thumbnails)
    }

    // MARK: - Lifecycle

    func start() {
        store.load()
        monitor.rulesProvider = { [unowned self] in self.prefs.captureRules }
        monitor.onCapture = { [unowned self] clip, source in self.processor.process(clip, source: source) }
        monitor.start()

        statusItemController = StatusItemController(controller: self)
        HotKeyManager.shared.onPressed = { [weak self] in
            MainActor.assumeIsolated { self?.togglePanel() }
        }
        let hotKeyOK = registerHotKey()
        DebugHooks.installIfEnabled(controller: self)

        if !prefs.hasLaunchedBefore {
            prefs.hasLaunchedBefore = true
            if LaunchAtLogin.isInApplicationsFolder {
                do { try LaunchAtLogin.set(true) } catch {
                    log.error("Login item registration failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            openSettings(welcome: true)
        } else if !hotKeyOK {
            openSettings()
        }
    }

    func shutdown() {
        monitor.stop()
        HotKeyManager.shared.unregister()
        store.flush()
    }

    // MARK: - Panel & settings

    func togglePanel(anchor: PanelController.Anchor = .preferred) {
        panelController.toggle(anchor: anchor)
    }

    func openSettings(welcome: Bool = false) {
        panelController.hide()
        settingsController.show(welcome: welcome)
    }

    func showStorageInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([persistence.baseURL])
    }

    func refreshStatus() {
        let granted = Permissions.accessibilityGranted
        if granted != accessibilityGranted { accessibilityGranted = granted }
        let access = Permissions.clipboardAccess
        if access != clipboardAccess { clipboardAccess = access }
        let enabled = LaunchAtLogin.isEnabled
        if enabled != loginEnabled { loginEnabled = enabled }
        let approval = LaunchAtLogin.needsApproval
        if approval != loginNeedsApproval { loginNeedsApproval = approval }
    }

    // MARK: - Debug (DebugHooks)

    func debugSetQuery(_ query: String) { panelController.model.query = query }
    func debugSnapshotPanel(to url: URL) { panelController.debugSnapshot(to: url) }
    func debugSnapshotSettings(to url: URL) {
        settingsController.show(welcome: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.settingsController.debugSnapshot(to: url)
        }
    }

    // MARK: - Shortcut

    @discardableResult
    func registerHotKey() -> Bool {
        let ok = HotKeyManager.shared.register(keyCode: prefs.shortcut.keyCode, carbonModifiers: prefs.shortcut.carbonModifiers)
        shortcutError = ok ? nil : "\(prefs.shortcut.display) is taken by another app — record a different shortcut."
        return ok
    }

    func beginShortcutRecording() {
        HotKeyManager.shared.unregister()
    }

    func endShortcutRecording() {
        if HotKeyManager.shared.register(keyCode: prefs.shortcut.keyCode, carbonModifiers: prefs.shortcut.carbonModifiers) {
            return
        }
        shortcutError = "\(prefs.shortcut.display) is taken by another app — record a different shortcut."
    }

    func applyShortcut(_ shortcut: Shortcut) {
        if HotKeyManager.shared.register(keyCode: shortcut.keyCode, carbonModifiers: shortcut.carbonModifiers) {
            prefs.shortcut = shortcut
            shortcutError = nil
        } else {
            shortcutError = "\(shortcut.display) is taken by another app — pick another."
            registerHotKey()
        }
    }

    // MARK: - History actions

    func requestLimitChange(to newLimit: Int) {
        guard newLimit != prefs.historyLimit else { return }
        let removed = store.evictionCount(forLimit: newLimit)
        if removed > 0 {
            NSApp.activate()
            let alert = NSAlert()
            alert.messageText = "Keep only the last \(newLimit) items?"
            alert.informativeText = "The \(removed) oldest unpinned \(removed == 1 ? "item" : "items") will be deleted. Pinned items are kept."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Delete \(removed) \(removed == 1 ? "Item" : "Items")")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else {
                prefs.objectWillChange.send()        // segmented control snaps back
                return
            }
        }
        prefs.historyLimit = newLimit
        store.setLimit(newLimit)
    }

    func confirmClearHistory() {
        let count = store.unpinnedCount
        guard count > 0 else { return }
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "\(count) \(count == 1 ? "item" : "items") will be deleted. Pinned items are kept."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { store.clearUnpinned() }
    }

    /// Not persisted: a restart never leaves capturing silently off.
    func setPaused(_ paused: Bool) {
        isPaused = paused
        monitor.isPaused = paused
        statusItemController?.setPaused(paused)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled)
        } catch {
            NSApp.activate()
            let alert = NSAlert()
            alert.messageText = enabled ? "Couldn't turn on Launch at Login" : "Couldn't turn off Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        refreshStatus()
    }
}
