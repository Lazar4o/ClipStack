import AppKit

/// Source-app icons for rows, looked up once per bundle ID.
@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    private var icons: [String: NSImage] = [:]
    private var misses = Set<String>()

    func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID, !misses.contains(bundleID) else { return nil }
        if let icon = icons[bundleID] { return icon }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            misses.insert(bundleID)
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        icons[bundleID] = icon
        return icon
    }
}
