import AppKit
import Carbon.HIToolbox

/// Menu-bar icon: left-click opens the panel below it, right-click (or ⌃-click) opens the menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private unowned let controller: AppController

    init(controller: AppController) {
        self.controller = controller
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "list.clipboard", accessibilityDescription: "ClipStack")
                ?? NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipStack")
            button.image?.isTemplate = true
            button.toolTip = "ClipStack"
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        menu.delegate = self
    }

    func setPaused(_ paused: Bool) {
        statusItem.button?.appearsDisabled = paused
        statusItem.button?.toolTip = paused ? "ClipStack (paused)" : "ClipStack"
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            statusItem.menu = menu            // show the menu only for this click…
            sender.performClick(nil)
            statusItem.menu = nil             // …so left-click keeps calling this action
        } else if let window = sender.window {
            let rect = window.convertToScreen(sender.convert(sender.bounds, to: nil))
            controller.togglePanel(anchor: .statusItem(rect))
        }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let open = item("Open History", #selector(openHistory))
        applyShortcut(controller.prefs.shortcut, to: open)
        menu.addItem(open)

        let keepLast = NSMenuItem(title: "Keep Last", action: nil, keyEquivalent: "")
        let keepMenu = NSMenu()
        for option in Preferences.limitOptions {
            let entry = item("\(option) items", #selector(keepLast(_:)))
            entry.tag = option
            entry.state = controller.prefs.historyLimit == option ? .on : .off
            keepMenu.addItem(entry)
        }
        keepLast.submenu = keepMenu
        menu.addItem(keepLast)

        let pause = item("Pause Capturing", #selector(togglePause))
        pause.state = controller.isPaused ? .on : .off
        menu.addItem(pause)
        menu.addItem(item("Clear History…", #selector(clearHistory)))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(item("Quit ClipStack", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    /// Shows the global shortcut next to "Open History" (display only).
    private func applyShortcut(_ shortcut: Shortcut, to item: NSMenuItem) {
        guard let name = Shortcut.keyName(for: UInt16(shortcut.keyCode)), name.count == 1 else { return }
        item.keyEquivalent = name.lowercased()
        var mask: NSEvent.ModifierFlags = []
        if shortcut.carbonModifiers & UInt32(cmdKey) != 0 { mask.insert(.command) }
        if shortcut.carbonModifiers & UInt32(shiftKey) != 0 { mask.insert(.shift) }
        if shortcut.carbonModifiers & UInt32(optionKey) != 0 { mask.insert(.option) }
        if shortcut.carbonModifiers & UInt32(controlKey) != 0 { mask.insert(.control) }
        item.keyEquivalentModifierMask = mask
    }

    @objc private func openHistory() { controller.togglePanel() }
    @objc private func keepLast(_ sender: NSMenuItem) { controller.requestLimitChange(to: sender.tag) }
    @objc private func togglePause() { controller.setPaused(!controller.isPaused) }
    @objc private func clearHistory() { controller.confirmClearHistory() }
    @objc private func openSettings() { controller.openSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
