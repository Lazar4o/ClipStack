import Foundation

public enum ClipFilter: String, CaseIterable, Sendable {
    case all, text, images, pinned

    public var title: String {
        switch self {
        case .all: return "All"
        case .text: return "Text"
        case .images: return "Images"
        case .pinned: return "Pinned"
        }
    }
}

public enum ClipSearch {
    /// Every whitespace-separated word must match (case- and accent-insensitive)
    /// the item's text, its source app name, or "image" for images.
    public static func filter(_ items: [ClipItem], query: String, filter: ClipFilter) -> [ClipItem] {
        let words = query.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return items.filter { item in
            switch filter {
            case .all: break
            case .text: guard item.kind == .text else { return false }
            case .images: guard item.kind == .image else { return false }
            case .pinned: guard item.isPinned else { return false }
            }
            return words.isEmpty || matches(item, words: words)
        }
    }

    public static func matches(_ item: ClipItem, words: [String]) -> Bool {
        var haystack = item.searchText ?? ""
        if let app = item.sourceAppName { haystack += "\n" + app }
        if item.kind == .image { haystack += "\nimage screenshot" }
        return words.allSatisfy { word in
            haystack.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
