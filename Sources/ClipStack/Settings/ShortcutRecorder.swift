import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Click, then press the new shortcut. Esc cancels.
struct ShortcutRecorder: View {
    @ObservedObject var controller: AppController
    @ObservedObject var prefs: Preferences
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(isRecording ? "Press shortcut…" : prefs.shortcut.display)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .frame(minWidth: 120)
        }
        .help(isRecording ? "Press the new shortcut, or Esc to cancel" : "Click to record a new shortcut")
        .onDisappear { stop() }
    }

    private func toggle() {
        if isRecording { stop() } else { start() }
    }

    private func start() {
        isRecording = true
        controller.beginShortcutRecording()          // unregister, so pressing the current combo doesn't open the panel
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { () -> Void in handle(event) }
            return nil                                // swallow every key while recording
        }
    }

    private func handle(_ event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            stop()
            return
        }
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let hasMainModifier = !mods.intersection([.command, .option, .control]).isEmpty
        guard hasMainModifier || Shortcut.isFunctionKey(event.keyCode),
              !Self.isReserved(keyCode: event.keyCode, mods: mods),
              let shortcut = Shortcut.make(keyCode: event.keyCode, flags: mods) else {
            NSSound.beep()
            return
        }
        controller.applyShortcut(shortcut)
        stop()
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if isRecording {
            isRecording = false
            controller.endShortcutRecording()        // re-registers whatever is current now
        }
    }

    /// ⌘-only combos everyone relies on: taking them globally would break every app.
    private static func isReserved(keyCode: UInt16, mods: NSEvent.ModifierFlags) -> Bool {
        guard mods == [.command] else { return false }
        let reserved = [kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_H, kVK_ANSI_M, kVK_ANSI_A, kVK_ANSI_C, kVK_ANSI_V,
                        kVK_ANSI_X, kVK_ANSI_Z, kVK_ANSI_S, kVK_ANSI_N, kVK_ANSI_T, kVK_Tab, kVK_Space]
        return reserved.contains(Int(keyCode))
    }
}
