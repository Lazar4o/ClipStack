import Carbon.HIToolbox
import CoreGraphics

/// Posts ⌘V to the frontmost app. Requires the Accessibility permission.
enum KeySimulator {
    static func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        // Keep keys the user is still physically holding (e.g. ⇧ from ⇧↩) out of the synthetic event.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        // Physical V key. ⌘-shortcuts on the Bulgarian layout use the Latin layout, so this works there too.
        let vKey = CGKeyCode(kVK_ANSI_V)
        // ⌘ plus the left-⌘ device bit (NX_DEVICELCMDKEYMASK); some apps check it.
        let flags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x0000_0008)
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }
}
