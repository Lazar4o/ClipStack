import AppKit

/// Development-only hooks. COMPILED OUT of release builds (scripts/install.sh builds release):
/// distributed notifications can be posted by any local process, so they must never ship.
/// Debug build: `CONFIG=debug scripts/install.sh`, then
/// `defaults write local.tools.ClipStack DebugHooks -bool YES` and relaunch.
/// Lets scripts open the panel, set the search query and render windows to PNG
/// (in-process rendering of ClipStack's own views; no screen capture).
///
///   swift scripts/debug-hook.swift toggle
///   swift scripts/debug-hook.swift query "clip 1"
///   swift scripts/debug-hook.swift snapshot /path/panel.png
///   swift scripts/debug-hook.swift settings /path/settings.png
@MainActor
enum DebugHooks {
    static let prefix = "local.tools.ClipStack.debug."

    static func installIfEnabled(controller: AppController) {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "DebugHooks") else { return }
        let center = DistributedNotificationCenter.default()
        func observe(_ name: String, _ handler: @escaping @MainActor (String?) -> Void) {
            center.addObserver(forName: Notification.Name(prefix + name), object: nil, queue: .main) { note in
                let argument = note.object as? String
                MainActor.assumeIsolated { handler(argument) }
            }
        }
        observe("toggle") { _ in controller.togglePanel() }
        observe("query") { query in controller.debugSetQuery(query ?? "") }
        observe("snapshot") { path in
            if let path { controller.debugSnapshotPanel(to: URL(fileURLWithPath: path)) }
        }
        observe("settings") { path in
            if let path { controller.debugSnapshotSettings(to: URL(fileURLWithPath: path)) }
        }
        #endif
    }

    /// Renders a view (and its subviews) onto an opaque background and writes a PNG.
    static func render(_ view: NSView, to url: URL) {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: view.bounds.size)).fill()
        rep.draw(in: NSRect(origin: .zero, size: view.bounds.size))
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}
