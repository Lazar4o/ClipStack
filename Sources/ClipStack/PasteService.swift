import AppKit
import ClipStackCore

/// Puts a history item back on the general pasteboard.
@MainActor
final class PasteService {
    private let store: HistoryStore
    private let monitor: PasteboardMonitor

    init(store: HistoryStore, monitor: PasteboardMonitor) {
        self.store = store
        self.monitor = monitor
    }

    /// Writes the item (all stored flavours, or plain text only) and moves it to the top of the history.
    func write(_ item: ClipItem, plainTextOnly: Bool) -> Bool {
        let files = store.persistence
        let pasteboardItem = NSPasteboardItem()

        switch item.kind {
        case .text:
            guard let text = files.loadText(item.id) else { return false }
            if !plainTextOnly {
                if item.hasRTF, let rtf = files.loadRTF(item.id) { pasteboardItem.setData(rtf, forType: .rtf) }
                if item.hasHTML, let html = files.loadHTML(item.id) { pasteboardItem.setData(html, forType: .html) }
            }
            pasteboardItem.setString(text, forType: .string)
        case .image:
            guard let png = files.loadPNG(item.id) else { return false }
            pasteboardItem.setData(png, forType: .png)
            // Some apps only read TIFF.
            if let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation(using: .lzw, factor: 0) {
                pasteboardItem.setData(tiff, forType: .tiff)
            }
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let ok = pasteboard.writeObjects([pasteboardItem])
        monitor.markOwnWrite(pasteboard.changeCount)        // read AFTER writing
        if ok { store.bump(item.id) }
        return ok
    }
}
