import Foundation

public enum ClipKind: String, Codable, Sendable {
    case text
    case image
}

/// One history entry. Payloads (full text, RTF, HTML, PNG, thumbnail) live in blob files;
/// this struct is what goes into `history.json`.
/// Any field added after v1 must be Optional so older files still decode.
public struct ClipItem: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var kind: ClipKind
    public var createdAt: Date
    /// Sort key (newest first). Bumped when the same content is copied again or picked from history.
    public var lastUsedAt: Date
    public var isPinned: Bool
    public var contentHash: String

    // Text
    public var previewText: String?
    public var searchText: String?
    public var charCount: Int?
    public var hasRTF: Bool
    public var hasHTML: Bool

    // Image
    public var pixelWidth: Int?
    public var pixelHeight: Int?

    // Common
    public var byteSize: Int
    public var sourceBundleID: String?
    public var sourceAppName: String?

    public init(
        id: UUID = UUID(),
        kind: ClipKind,
        createdAt: Date,
        lastUsedAt: Date,
        isPinned: Bool = false,
        contentHash: String,
        previewText: String? = nil,
        searchText: String? = nil,
        charCount: Int? = nil,
        hasRTF: Bool = false,
        hasHTML: Bool = false,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        byteSize: Int,
        sourceBundleID: String? = nil,
        sourceAppName: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.isPinned = isPinned
        self.contentHash = contentHash
        self.previewText = previewText
        self.searchText = searchText
        self.charCount = charCount
        self.hasRTF = hasRTF
        self.hasHTML = hasHTML
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteSize = byteSize
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
    }
}
