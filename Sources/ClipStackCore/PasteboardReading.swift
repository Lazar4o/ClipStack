import AppKit

/// Minimal read access to a pasteboard so capture rules can be unit-tested with a fake.
/// (Names differ from NSPasteboard's own `string(forType:)` on purpose: overloading causes ambiguity.)
public protocol PasteboardReading {
    var availableTypes: [String] { get }
    func readString(type: String) -> String?
    func readData(type: String) -> Data?
}

extension NSPasteboard: PasteboardReading {
    public var availableTypes: [String] { (types ?? []).map(\.rawValue) }

    public func readString(type: String) -> String? {
        string(forType: NSPasteboard.PasteboardType(type))
    }

    public func readData(type: String) -> Data? {
        data(forType: NSPasteboard.PasteboardType(type))
    }
}

/// Uniform type identifiers used by ClipStack.
public enum PasteboardTypes {
    public static let plainText = "public.utf8-plain-text"
    public static let rtf = "public.rtf"
    public static let html = "public.html"
    public static let png = "public.png"
    public static let tiff = "public.tiff"
    public static let jpeg = "public.jpeg"
    public static let heic = "public.heic"
    public static let fileURL = "public.file-url"
    /// nspasteboard.org convention: bundle ID of the app that wrote the data.
    public static let source = "org.nspasteboard.source"
}
