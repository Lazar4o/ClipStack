import AppKit
import ClipStackCore
import os

/// Where a copy came from: the nspasteboard.org source marker if present, else the frontmost app.
/// (The frontmost app is right because our panel never activates ClipStack.)
struct SourceApp: Sendable {
    var bundleID: String?
    var name: String?

    static func detect(_ pasteboard: NSPasteboard) -> SourceApp {
        if let id = pasteboard.string(forType: NSPasteboard.PasteboardType(PasteboardTypes.source)), !id.isEmpty {
            let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?
                .deletingPathExtension().lastPathComponent
            return SourceApp(bundleID: id, name: name)
        }
        let app = NSWorkspace.shared.frontmostApplication
        return SourceApp(bundleID: app?.bundleIdentifier, name: app?.localizedName)
    }
}

/// macOS has no clipboard-changed notification: poll `changeCount` (cheap) and read contents
/// only when it changes (reading contents is what may trigger the macOS paste-privacy alert).
@MainActor
final class PasteboardMonitor {
    var isPaused = false
    var rulesProvider: () -> CaptureRules = { CaptureRules() }
    var onCapture: ((CapturedClip, SourceApp) -> Void)?

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount = -1             // -1 → the current clipboard is captured once at launch
    private var ownWrites = Set<Int>()           // changeCounts produced by PasteService
    private var timer: Timer?
    private let log = Logger(subsystem: "local.tools.ClipStack", category: "capture")

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)    // .common: keeps firing while a menu is open
        timer = t
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Called by PasteService right after it writes, with the changeCount read after the write.
    func markOwnWrite(_ changeCount: Int) {
        ownWrites.insert(changeCount)
    }

    private func tick() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        if ownWrites.remove(count) != nil { return }        // our own paste, not a new clip
        ownWrites = ownWrites.filter { $0 > count }          // drop stale entries
        guard !isPaused else { return }

        let source = SourceApp.detect(pasteboard)
        guard let clip = ClipClassifier.classify(pasteboard, sourceBundleID: source.bundleID, rules: rulesProvider()) else {
            log.debug("change \(count): ignored (types: \(self.pasteboard.types?.count ?? 0))")
            return
        }
        switch clip {
        case .text(let plain, let rtf, let html):
            log.debug("change \(count): text \(plain.utf8.count) B rtf=\(rtf != nil) html=\(html != nil) from \(source.bundleID ?? "?", privacy: .public)")
        case .image(let data, let uti):
            log.debug("change \(count): image \(uti, privacy: .public) \(data.count) B from \(source.bundleID ?? "?", privacy: .public)")
        }
        onCapture?(clip, source)
    }
}
