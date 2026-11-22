import ClipStackCore
import SwiftUI

struct HistoryActions {
    var pick: (ClipItem, _ plainText: Bool) -> Void
    var copyOnly: (ClipItem) -> Void
    var togglePin: (ClipItem) -> Void
    var delete: (ClipItem) -> Void
    var openSettings: () -> Void
}

/// Root view of the floating panel (sits on Liquid Glass; keep backgrounds translucent).
struct HistoryView: View {
    @ObservedObject var model: HistoryViewModel
    @ObservedObject var prefs: Preferences
    let thumbnails: ThumbnailCache
    let actions: HistoryActions

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            content
            Divider().opacity(0.5)
            footer
        }
        .frame(width: PanelMetrics.width, height: PanelMetrics.height)
        .clipShape(RoundedRectangle(cornerRadius: PanelMetrics.cornerRadius, style: .continuous))
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                SearchField(text: $model.query, focusRequest: model.focusRequest)
                    .frame(height: 24)
                if !model.query.isEmpty {
                    Button { model.query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            HStack(spacing: 6) {
                ForEach(ClipFilter.allCases, id: \.self) { filter in
                    filterChip(filter)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
    }

    private func filterChip(_ filter: ClipFilter) -> some View {
        let selected = model.filter == filter
        return Button { model.filter = filter } label: {
            Text(filter.title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(selected ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.06)))
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - List

    @ViewBuilder private var content: some View {
        if model.visible.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(model.visible.enumerated()), id: \.element.id) { index, item in
                            ClipRowView(item: item, index: index, isSelected: index == model.selectedIndex,
                                        thumbnails: thumbnails)
                                .contentShape(Rectangle())          // whole row is clickable
                                .onTapGesture { actions.pick(item, false) }
                                .contextMenu { contextMenu(for: item) }
                        }
                    }
                    .padding(8)
                }
                .onChange(of: model.selectedIndex) { _, newIndex in
                    guard model.visible.indices.contains(newIndex) else { return }
                    proxy.scrollTo(model.visible[newIndex].id)
                }
                .onChange(of: model.focusRequest) { _, _ in
                    if let first = model.visible.first { proxy.scrollTo(first.id, anchor: .top) }
                }
            }
        }
    }

    @ViewBuilder private func contextMenu(for item: ClipItem) -> some View {
        Button(prefs.pasteMode == .autoPaste ? "Paste" : "Copy") { actions.pick(item, false) }
        if item.kind == .text {
            Button(prefs.pasteMode == .autoPaste ? "Paste as Plain Text" : "Copy as Plain Text") { actions.pick(item, true) }
        }
        if prefs.pasteMode == .autoPaste {
            Button("Copy Without Pasting") { actions.copyOnly(item) }
        }
        Divider()
        Button(item.isPinned ? "Unpin" : "Pin") { actions.togglePin(item) }
        Button("Delete", role: .destructive) { actions.delete(item) }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: model.query.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            if model.query.isEmpty {
                Text(model.filter == .pinned ? "No pinned items" : "Nothing here yet")
                    .font(.system(size: 14, weight: .semibold))
                Text(model.filter == .pinned
                     ? "Press ⌘P on an item to keep it forever."
                     : "Copy some text or take a screenshot (⌘⇧4).")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text(verbatim: "No matches for “\(model.query)”")      // verbatim: never parse Markdown/links
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Text(countText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            if model.accessibilityWarning {
                Button(action: actions.openSettings) {
                    Label("Paste needs Accessibility", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            } else {
                Text(hintText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Button(action: actions.openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
    }

    private var countText: String {
        var text = "\(model.unpinnedCount) of \(prefs.historyLimit)"
        if model.pinnedCount > 0 { text += " · \(model.pinnedCount) pinned" }
        return text
    }

    private var hintText: String {
        prefs.pasteMode == .autoPaste
            ? "↩ Paste   ⇧↩ Plain   ⌘P Pin   ⌘⌫ Delete"
            : "↩ Copy   ⇧↩ Plain   ⌘P Pin   ⌘⌫ Delete"
    }
}
