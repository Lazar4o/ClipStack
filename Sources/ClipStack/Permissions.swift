import AppKit
import ApplicationServices
import ServiceManagement

enum Permissions {
    /// Updates live once the user flips the switch; no relaunch needed.
    static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt (once) and adds ClipStack to the Accessibility list.
    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String   // Unmanaged<CFString>
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    /// Privacy & Security (the user then scrolls to "Paste from Other Apps").
    static func openPrivacySettings() {
        open("x-apple.systempreferences:com.apple.preference.security")
    }

    enum ClipboardAccess { case allowed, ask, denied }

    /// macOS 15.4+ paste-privacy setting for ClipStack ("Paste from Other Apps").
    static var clipboardAccess: ClipboardAccess {
        switch NSPasteboard.general.accessBehavior {
        case .alwaysDeny: return .denied
        case .ask: return .ask
        case .alwaysAllow, .default: return .allowed
        @unknown default: return .allowed
        }
    }

    private static func open(_ string: String) {
        if let url = URL(string: string), NSWorkspace.shared.open(url) { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}

enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Only register a login item for an installed copy (not a build folder).
    static var isInApplicationsFolder: Bool {
        let path = Bundle.main.bundleURL.path
        return path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }
}
