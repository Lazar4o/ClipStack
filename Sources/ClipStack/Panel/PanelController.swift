import AppKit
import Carbon.HIToolbox
import ClipStackCore
import SwiftUI

/// Shows/hides the history panel, handles its keyboard and runs the paste flow.
@MainActor
final class PanelController {
    enum Anchor {
        case preferred              // mouse cursor or screen center (Settings)
        case statusItem(NSRect)     // below the menu-bar icon (screen coordinates)
    }

    let model: HistoryViewModel
    var onOpenSettings: (() -> Void)?

    private let panel: FloatingPanel
    private let store: HistoryStore
    private let prefs: Preferences
    private let pasteService: PasteService
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?
    private var lastHideTime = Date.distantPast

    // ⌘1…⌘9: key codes are NOT sequential (0x12,0x13,0x14,0x15,0x17,0x16,0x1A,0x1C,0x19).
    private static let digitKeyCodes = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                                        kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]

    init(store: HistoryStore, prefs: Preferences, thumbnails: ThumbnailCache, pasteService: PasteService) {
        self.store = store
        self.prefs = prefs
        self.pasteService = pasteService
        model = HistoryViewModel(store: store)
        let size = NSSize(width: PanelMetrics.width, height: PanelMetrics.height)
        panel = FloatingPanel(size: size)

        let actions = HistoryActions(
            pick: { [weak self] item, plain in self?.pick(item, plainText: plain) },
            copyOnly: { [weak self] item in self?.copyOnly(item) },
            togglePin: { [weak self] item in self?.store.togglePin(item.id) },
            delete: { [weak self] item in self?.store.delete(item.id) },
            openSettings: { [weak self] in self?.openSettings() }
        )
        let hosting = NSHostingView(rootView: HistoryView(model: model, prefs: prefs, thumbnails: thumbnails, actions: actions))
        hosting.sizingOptions = []                    // don't let SwiftUI resize the panel
        let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: size))
        glass.style = .regular
        glass.cornerRadius = PanelMetrics.cornerRadius
        hosting.frame = glass.bounds
        hosting.autoresizingMask = [.width, .height]
        glass.contentView = hosting
        panel.contentView = glass

        panel.onResignKey = { [weak self] in self?.hide() }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(anchor: Anchor = .preferred) {
        if panel.isVisible {
            hide()
            return
        }
        // A click on the menu-bar icon first makes the panel resign key (closing it); don't reopen it.
        if case .statusItem = anchor, Date().timeIntervalSince(lastHideTime) < 0.25 { return }
        show(anchor: anchor)
    }

    func show(anchor: Anchor = .preferred) {
        let front = NSWorkspace.shared.frontmostApplication
        // If ClipStack itself is in front (Settings open), there is no app to paste into → copy only.
        previousApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
        model.accessibilityWarning = prefs.pasteMode == .autoPaste && !Permissions.accessibilityGranted
        model.prepareForShow()
        position(anchor)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()                // NEVER NSApp.activate here: the previous app must stay active
        if let field = panel.initialFirstResponder { panel.makeFirstResponder(field) }
        panel.invalidateShadow()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            self.panel.animator().alphaValue = 1
        }
        installKeyMonitor()
    }

    func hide() {
        guard panel.isVisible else { return }
        removeKeyMonitor()
        panel.orderOut(nil)
        lastHideTime = Date()
    }

    func debugSnapshot(to url: URL) {
        guard let hosting = (panel.contentView as? NSGlassEffectView)?.contentView else { return }
        DebugHooks.render(hosting, to: url)
    }

    // MARK: - Picking

    private func pick(_ item: ClipItem, plainText: Bool) {
        guard pasteService.write(item, plainTextOnly: plainText) else {
            NSSound.beep()
            return
        }
        let target = previousApp
        hide()
        guard prefs.pasteMode == .autoPaste, target != nil, Permissions.accessibilityGranted else { return }
        let wasActive = NSApp.isActive
        if wasActive { NSApp.hide(nil) }        // shouldn't happen with a non-activating panel; safety net
        DispatchQueue.main.asyncAfter(deadline: .now() + (wasActive ? 0.15 : 0.05)) {
            KeySimulator.pressCommandV()
        }
    }

    private func copyOnly(_ item: ClipItem) {
        guard pasteService.write(item, plainTextOnly: false) else {
            NSSound.beep()
            return
        }
        hide()
    }

    private func pick(index: Int, plainText: Bool) {
        guard model.visible.indices.contains(index) else {
            NSSound.beep()
            return
        }
        pick(model.visible[index], plainText: plainText)
    }

    private func openSettings() {
        hide()
        onOpenSettings?()
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let swallow = MainActor.assumeIsolated { () -> Bool in
                guard let self, event.window === self.panel else { return false }
                return self.handleKey(event)
            }
            return swallow ? nil : event                         // nil = swallow
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Matches key codes, not characters, so everything works on the Bulgarian layout too.
    private func handleKey(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = mods.contains(.command)
        let shift = mods.contains(.shift)
        let code = Int(event.keyCode)

        switch code {
        case kVK_DownArrow:
            model.moveSelection(by: 1)
        case kVK_UpArrow:
            model.moveSelection(by: -1)
        case kVK_PageDown:
            model.moveSelection(by: 5)
        case kVK_PageUp:
            model.moveSelection(by: -5)
        case kVK_Return, kVK_ANSI_KeypadEnter:
            pick(index: model.selectedIndex, plainText: shift)
        case kVK_Escape:
            if model.query.isEmpty { hide() } else { model.query = "" }
        case kVK_Tab:
            model.cycleFilter(forward: !shift)
        case kVK_Delete where command:
            if let item = model.selectedItem { store.delete(item.id) }
        case kVK_ANSI_P where command:
            if let item = model.selectedItem { store.togglePin(item.id) }
        case kVK_ANSI_Comma where command:
            openSettings()
        default:
            if command, !shift, let n = Self.digitKeyCodes.firstIndex(of: code) {
                pick(index: n, plainText: false)
                return true
            }
            return false      // typing, ⌘A/⌘C/⌘V/⌘X/⌘Z (hidden Edit menu) go to the search field
        }
        return true
    }

    // MARK: - Position

    /// AppKit coordinates: origin bottom-left; `NSEvent.mouseLocation` is global.
    private func position(_ anchor: Anchor) {
        let size = panel.frame.size
        let mouse = NSEvent.mouseLocation
        let screen: NSScreen?
        var origin: NSPoint

        switch anchor {
        case .statusItem(let rect):
            screen = NSScreen.screens.first { $0.frame.intersects(rect) } ?? NSScreen.main
            origin = NSPoint(x: rect.midX - size.width / 2, y: rect.minY - size.height - 6)
        case .preferred:
            screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
            switch prefs.panelPosition {
            case .mouse:
                origin = NSPoint(x: mouse.x - 24, y: mouse.y - size.height + 12)
            case .center:
                let vf = screen?.visibleFrame ?? .zero
                origin = NSPoint(x: vf.midX - size.width / 2, y: vf.midY - size.height / 2 + vf.height * 0.08)
            }
        }

        guard let visible = screen?.visibleFrame else { return }
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        panel.setFrameOrigin(origin)
    }
}
