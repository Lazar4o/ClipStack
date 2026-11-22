import AppKit
import SwiftUI

final class SettingsUIState: ObservableObject {
    @Published var showWelcome = false
}

/// A plain NSWindow hosting SwiftUI (SwiftUI's Settings scene can't be opened reliably from an accessory app).
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private unowned let controller: AppController
    private let uiState = SettingsUIState()
    private var window: NSWindow?
    private var statusTimer: Timer?

    init(controller: AppController) {
        self.controller = controller
    }

    func show(welcome: Bool) {
        if window == nil {
            let view = SettingsView(controller: controller, prefs: controller.prefs, store: controller.store, ui: uiState)
            let hosting = NSHostingController(rootView: view)
            hosting.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: hosting)
            window.title = "ClipStack Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false          // otherwise reopening after close crashes
            window.delegate = self
            window.center()
            self.window = window
        }
        if welcome { uiState.showWelcome = true }
        controller.refreshStatus()
        startStatusTimer()
        NSApp.activate()                                 // accessory app: else the window opens behind others
        window?.makeKeyAndOrderFront(nil)
    }

    func debugSnapshot(to url: URL) {
        guard let view = window?.contentView else { return }
        DebugHooks.render(view, to: url)
    }

    func windowWillClose(_ notification: Notification) {
        statusTimer?.invalidate()
        statusTimer = nil
        uiState.showWelcome = false
    }

    /// Accessibility / clipboard-access / login-item status can change in System Settings at any time.
    private func startStatusTimer() {
        guard statusTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.controller.refreshStatus() }
        }
        RunLoop.main.add(timer, forMode: .common)
        statusTimer = timer
    }
}
