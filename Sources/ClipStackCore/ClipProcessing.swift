import Foundation

/// Payloads written to blob files.
public struct ClipBlobs: Sendable {
    public var text: String?
    public var rtf: Data?
    public var html: Data?
    public var png: Data?
    public var thumbnail: Data?

    public init(text: String? = nil, rtf: Data? = nil, html: Data? = nil, png: Data? = nil, thumbnail: Data? = nil) {
        self.text = text
        self.rtf = rtf
        self.html = html
        self.png = png
        self.thumbnail = thumbnail
    }

    public var byteSize: Int {
        (text.map { $0.utf8.count } ?? 0) + (rtf?.count ?? 0) + (html?.count ?? 0)
            + (png?.count ?? 0) + (thumbnail?.count ?? 0)
    }
}

/// A captured clip after hashing and normalizing, ready for `HistoryStore.insertOrBump`.
public struct ProcessedClip: Sendable {
    public var kind: ClipKind
    public var contentHash: String
    public var previewText: String?
    public var searchText: String?
    public var charCount: Int?
    public var pixelWidth: Int?
    public var pixelHeight: Int?
    public var blobs: ClipBlobs

    public init(kind: ClipKind, contentHash: String, previewText: String? = nil, searchText: String? = nil,
                charCount: Int? = nil, pixelWidth: Int? = nil, pixelHeight: Int? = nil, blobs: ClipBlobs) {
        self.kind = kind
        self.contentHash = contentHash
        self.previewText = previewText
        self.searchText = searchText
        self.charCount = charCount
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.blobs = blobs
    }
}

public enum ClipProcessing {
    public static let previewLength = 300
    public static let searchLength = 10_000
    public static let thumbnailMaxPixel = 720

    /// CPU-heavy for images (PNG encode + thumbnail): call off the main thread.
    public static func process(_ clip: CapturedClip) -> ProcessedClip? {
        switch clip {
        case let .text(plain, rtf, html):
            return ProcessedClip(
                kind: .text,
                contentHash: Hashing.textHash(plain),
                previewText: makePreview(plain),
                searchText: String(plain.prefix(searchLength)),
                charCount: plain.count,
                blobs: ClipBlobs(text: plain, rtf: rtf, html: html)
            )
        case let .image(data, uti):
            guard let normalized = ImageProcessing.normalizeToPNG(data, uti: uti) else { return nil }
            let thumbnail = ImageProcessing.thumbnailPNG(fromPNG: normalized.png, maxPixel: thumbnailMaxPixel)
            return ProcessedClip(
                kind: .image,
                contentHash: Hashing.imageHash(data),
                pixelWidth: normalized.width,
                pixelHeight: normalized.height,
                blobs: ClipBlobs(png: normalized.png, thumbnail: thumbnail)
            )
        }
    }

    /// First characters for the row; leading blank lines removed, tabs shown as spaces.
    static func makePreview(_ text: String) -> String {
        let trimmed = text.drop { $0 == "\n" || $0 == "\r" || $0 == " " || $0 == "\t" }
        return String(trimmed.prefix(previewLength)).replacingOccurrences(of: "\t", with: "    ")
    }
}
