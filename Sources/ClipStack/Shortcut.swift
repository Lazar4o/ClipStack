import AppKit
import Carbon.HIToolbox

/// A global shortcut: Carbon key code + Carbon modifier mask + display string.
/// Carbon masks are NOT NSEvent flags: cmdKey 0x100, shiftKey 0x200, optionKey 0x800, controlKey 0x1000.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var display: String

    static let defaultShortcut = Shortcut(
        keyCode: UInt32(kVK_ANSI_V),
        carbonModifiers: UInt32(cmdKey | shiftKey),
        display: "⇧⌘V"
    )

    /// Builds a shortcut from a key event. Names come from a key-code table (layout independent),
    /// so recording on the Bulgarian layout still shows Latin letters, matching the physical key.
    static func make(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Shortcut? {
        guard let name = keyName(for: keyCode) else { return nil }
        let mods = flags.intersection([.command, .option, .control, .shift])
        return Shortcut(keyCode: UInt32(keyCode), carbonModifiers: carbonModifiers(from: mods),
                        display: modifierSymbols(mods) + name)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        if flags.contains(.shift) { mask |= UInt32(shiftKey) }
        if flags.contains(.option) { mask |= UInt32(optionKey) }
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        return mask
    }

    /// Fixed macOS order: ⌃ ⌥ ⇧ ⌘.
    static func modifierSymbols(_ flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }

    static func isFunctionKey(_ keyCode: UInt16) -> Bool { functionKeys[Int(keyCode)] != nil }

    static func keyName(for keyCode: UInt16) -> String? {
        let code = Int(keyCode)
        return characterKeys[code] ?? specialKeys[code] ?? functionKeys[code]
    }

    // Key codes are not sequential: always look them up, never compute them.
    private static let characterKeys: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E",
        kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J",
        kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
        kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X", kVK_ANSI_Y: "Y",
        kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
        kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".",
        kVK_ANSI_Slash: "/", kVK_ANSI_Backslash: "\\", kVK_ANSI_Grave: "`",
    ]

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    ]

    private static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]
}
