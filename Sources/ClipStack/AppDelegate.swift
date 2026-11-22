import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var sigtermSource: DispatchSourceSignal?   // must stay alive
    private(set) var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard isOnlyInstance() else {
            NSApp.terminate(nil)
            return
        }
        installSIGTERMHandler()
        MainMenu.install(settingsTarget: self, settingsAction: #selector(openSettings))

        let controller = AppController()
        self.controller = controller
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }

    /// Opening the app again from Finder/Spotlight while it runs → show Settings, so something visibly happens.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.openSettings()
        return false
    }

    @objc func openSettings() {
        controller?.openSettings()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: - Lifecycle helpers

    private func isOnlyInstance() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return true }
        let me = ProcessInfo.processInfo.processIdentifier
        return !NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .contains { $0.processIdentifier != me && !$0.isTerminated }
    }

    /// `kill -TERM` (used by install.sh) → normal terminate, so applicationWillTerminate flushes history.
    private func installSIGTERMHandler() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApp.terminate(nil) }
        source.resume()
        sigtermSource = source
    }
}
