import AppKit

enum PanelMetrics {
    static let width: CGFloat = 440
    static let height: CGFloat = 560
    static let cornerRadius: CGFloat = 22
}

/// Borderless, non-activating floating panel: it takes keyboard input while the app you were in
/// stays active, so a synthetic ⌘V lands there after the panel closes.
final class FloatingPanel: NSPanel {
    var onResignKey: (() -> Void)?

    init(size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],    // .nonactivatingPanel must be set here, not later
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.auxiliary, .stationary, .moveToActiveSpace, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        animationBehavior = .none
        isMovableByWindowBackground = false
    }

    // Borderless windows can't become key by default → typing would go nowhere.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}
