import AppKit

enum PanelMetrics {
    static let width: CGFloat = 440
    static let height: CGFloat = 560
    static let cornerRadius: CGFloat = 22
    /// Transparent space around the glass for our own rounded shadow.
    static let shadowMargin: CGFloat = 28
}

/// Window content: glass + shadow. Clicks in the transparent margin are not handled
/// (the margin only exists to draw the shadow).
final class PanelContainerView: NSView {
    private let glassFrame: NSRect

    init(frame: NSRect, glassFrame: NSRect) {
        self.glassFrame = glassFrame
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard glassFrame.contains(local) else { return nil }
        return super.hitTest(point)
    }
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
        hasShadow = false        // the system shadow follows the square window bounds; PanelController draws a rounded one
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
