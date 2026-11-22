import Combine
import ClipStackCore
import Foundation

/// State of the history panel: query, filter, visible items and keyboard selection.
@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var query = "" {
        didSet { if query != oldValue { recompute(resetSelection: true) } }
    }
    @Published var filter: ClipFilter = .all {
        didSet { if filter != oldValue { recompute(resetSelection: true) } }
    }
    @Published private(set) var visible: [ClipItem] = []
    @Published var selectedIndex = 0
    /// Incremented on every show; the search field focuses itself when it changes.
    @Published private(set) var focusRequest = 0
    @Published var accessibilityWarning = false
    @Published private(set) var unpinnedCount = 0
    @Published private(set) var pinnedCount = 0

    private var allItems: [ClipItem] = []
    private var cancellable: AnyCancellable?

    init(store: HistoryStore) {
        // @Published emits BEFORE the property changes: use the value passed in, not store.items.
        cancellable = store.$items.sink { [weak self] items in
            MainActor.assumeIsolated {
                self?.allItems = items
                self?.recompute(resetSelection: false)
            }
        }
    }

    var selectedItem: ClipItem? {
        visible.indices.contains(selectedIndex) ? visible[selectedIndex] : nil
    }

    func prepareForShow() {
        query = ""
        filter = .all
        recompute(resetSelection: true)
        focusRequest += 1
    }

    func moveSelection(by delta: Int) {
        guard !visible.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), visible.count - 1)
    }

    func cycleFilter(forward: Bool) {
        let all = ClipFilter.allCases
        guard let index = all.firstIndex(of: filter) else { return }
        filter = all[(index + (forward ? 1 : all.count - 1)) % all.count]
    }

    private func recompute(resetSelection: Bool) {
        let previousID = selectedItem?.id
        visible = ClipSearch.filter(allItems, query: query, filter: filter)
        unpinnedCount = allItems.lazy.filter { !$0.isPinned }.count
        pinnedCount = allItems.count - unpinnedCount
        if resetSelection {
            selectedIndex = 0
        } else if let previousID, let index = visible.firstIndex(where: { $0.id == previousID }) {
            selectedIndex = index
        } else {
            selectedIndex = min(selectedIndex, max(visible.count - 1, 0))
        }
    }
}
