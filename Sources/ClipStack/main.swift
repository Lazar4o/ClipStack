import AppKit

@MainActor
enum AppMain {
    /// Static on purpose: NSApplication.delegate is weak, so a local could be released early.
    static let delegate = AppDelegate()

    static func run() {
        NSApplication.shared.delegate = delegate
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.run()
    }
}

// Top-level code runs on the main thread; tell the compiler so it can call main-actor code.
MainActor.assumeIsolated { AppMain.run() }
