import AppKit
import ClipStackCore
import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    let thumbnails: ThumbnailCache

    @State private var hovering = false
    @State private var loadedThumbnail: NSImage?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            leadingIcon
            VStack(alignment: .leading, spacing: 5) {
                content
                Text(metaText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 6) {
                if index < 9 {
                    Text("⌘\(index + 1)")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.22) : (hovering ? Color.primary.opacity(0.06) : .clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(isSelected ? 0.45 : 0), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.1), value: isSelected)
        .onHover { hovering = $0 }
        .task(id: item.id) {
            guard item.kind == .image, thumbnails.cached(item.id) == nil else { return }
            loadedThumbnail = await thumbnails.load(item.id)
        }
    }

    // MARK: - Parts

    @ViewBuilder private var leadingIcon: some View {
        if let icon = AppIconCache.shared.icon(for: item.sourceBundleID) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 26, height: 26)
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: item.kind == .text ? "doc.text" : "photo")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.07)))
        }
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .text:
            Text(item.previewText ?? "")
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
        case .image:
            if let image = loadedThumbnail ?? thumbnails.cached(item.id) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
                    .frame(maxWidth: .infinity, maxHeight: 120, alignment: .leading)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 80)
            }
        }
    }

    private var metaText: String {
        var parts: [String] = []
        switch item.kind {
        case .text:
            if let app = item.sourceAppName { parts.append(app) }
            parts.append(RelativeTime.compact(item.lastUsedAt))
            if let count = item.charCount { parts.append("\(count.formatted()) \(count == 1 ? "char" : "chars")") }
        case .image:
            parts.append("Image")
            if let w = item.pixelWidth, let h = item.pixelHeight { parts.append("\(w)×\(h)") }
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(item.byteSize), countStyle: .file))
            parts.append(RelativeTime.compact(item.lastUsedAt))
        }
        return parts.joined(separator: " · ")
    }
}

enum RelativeTime {
    private static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f
    }()

    private static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f
    }()

    /// now / 5m / 3h / Yesterday / Mon / 12 Mar
    static func compact(_ date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "\(Int(seconds / 3600))h" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if seconds < 6 * 86_400 { return weekday.string(from: date) }
        return dayMonth.string(from: date)
    }
}
