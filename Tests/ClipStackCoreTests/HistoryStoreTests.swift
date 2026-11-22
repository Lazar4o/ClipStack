import XCTest
@testable import ClipStackCore

final class HistoryStoreTests: XCTestCase {
    private func blobExists(_ store: HistoryStore, _ id: UUID, _ kind: HistoryPersistence.BlobKind = .text) -> Bool {
        store.persistence.waitForPendingWork()
        return FileManager.default.fileExists(atPath: store.persistence.blobURL(id, kind).path)
    }

    func testLimitEvictsOldestAndDeletesBlobs() {
        let store = makeStore(limit: 10)
        let inserted = (1...12).map { store.insertOrBump(textClip("clip \($0)"), sourceBundleID: nil, sourceAppName: nil) }
        XCTAssertEqual(store.items.count, 10)
        XCTAssertEqual(store.items.first?.previewText, "clip 12")
        XCTAssertEqual(store.items.last?.previewText, "clip 3")
        XCTAssertFalse(blobExists(store, inserted[0].id))
        XCTAssertFalse(blobExists(store, inserted[1].id))
        XCTAssertTrue(blobExists(store, inserted[2].id))
    }

    func testPinnedItemsSurviveAndDoNotCount() {
        let store = makeStore(limit: 3)
        let first = store.insertOrBump(textClip("keep me"), sourceBundleID: nil, sourceAppName: nil)
        store.togglePin(first.id)
        for i in 1...5 { store.insertOrBump(textClip("n\(i)"), sourceBundleID: nil, sourceAppName: nil) }
        XCTAssertEqual(store.unpinnedCount, 3)
        XCTAssertEqual(store.pinnedCount, 1)
        XCTAssertNotNil(store.item(withID: first.id))
        XCTAssertTrue(blobExists(store, first.id))
    }

    func testDuplicateBumpsInsteadOfAdding() {
        let store = makeStore(limit: 10)
        let a = store.insertOrBump(textClip("a"), sourceBundleID: nil, sourceAppName: nil)
        store.insertOrBump(textClip("b"), sourceBundleID: nil, sourceAppName: nil)
        let again = store.insertOrBump(textClip("a"), sourceBundleID: "com.apple.Safari", sourceAppName: "Safari")
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(again.id, a.id)
        XCTAssertEqual(store.items.first?.id, a.id)
        XCTAssertEqual(store.items.first?.sourceAppName, "Safari")
    }

    func testBumpMovesToTop() {
        let store = makeStore(limit: 10)
        let a = store.insertOrBump(textClip("a"), sourceBundleID: nil, sourceAppName: nil)
        store.insertOrBump(textClip("b"), sourceBundleID: nil, sourceAppName: nil)
        store.bump(a.id)
        XCTAssertEqual(store.items.map(\.previewText), ["a", "b"])
    }

    func testSetLimitEvictsAndEvictionCount() {
        let store = makeStore(limit: 50)
        for i in 1...30 { store.insertOrBump(textClip("x\(i)"), sourceBundleID: nil, sourceAppName: nil) }
        XCTAssertEqual(store.evictionCount(forLimit: 10), 20)
        XCTAssertEqual(store.evictionCount(forLimit: 100), 0)
        store.setLimit(10)
        XCTAssertEqual(store.items.count, 10)
        XCTAssertEqual(store.items.first?.previewText, "x30")
    }

    func testUnpinDoesNotEvictImmediately() {
        let store = makeStore(limit: 2)
        let old = store.insertOrBump(textClip("old"), sourceBundleID: nil, sourceAppName: nil)
        store.togglePin(old.id)
        store.insertOrBump(textClip("b"), sourceBundleID: nil, sourceAppName: nil)
        store.insertOrBump(textClip("c"), sourceBundleID: nil, sourceAppName: nil)
        store.togglePin(old.id)                       // now 3 unpinned with limit 2
        XCTAssertEqual(store.items.count, 3)
        store.insertOrBump(textClip("d"), sourceBundleID: nil, sourceAppName: nil)
        XCTAssertEqual(store.items.map(\.previewText), ["d", "c"])
    }

    func testClearUnpinnedKeepsPins() {
        let store = makeStore(limit: 10)
        let pinned = store.insertOrBump(textClip("pinned"), sourceBundleID: nil, sourceAppName: nil)
        store.togglePin(pinned.id)
        let other = store.insertOrBump(textClip("other"), sourceBundleID: nil, sourceAppName: nil)
        store.clearUnpinned()
        XCTAssertEqual(store.items.map(\.id), [pinned.id])
        XCTAssertFalse(blobExists(store, other.id))
        store.clearAll()
        XCTAssertTrue(store.items.isEmpty)
    }

    func testDeleteRemovesBlobs() {
        let store = makeStore(limit: 10)
        let item = store.insertOrBump(textClip("bye", rtf: Data("{\\rtf1 bye}".utf8)), sourceBundleID: nil, sourceAppName: nil)
        XCTAssertTrue(blobExists(store, item.id, .rtf))
        store.delete(item.id)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertFalse(blobExists(store, item.id, .text))
        XCTAssertFalse(blobExists(store, item.id, .rtf))
    }

    func testSearchAndFilters() {
        let store = makeStore(limit: 10)
        store.insertOrBump(textClip("Привет свят"), sourceBundleID: nil, sourceAppName: "Notes")
        store.insertOrBump(textClip("Café au lait"), sourceBundleID: nil, sourceAppName: "Safari")
        let image = ClipProcessing.process(.image(data: TestImages.make(width: 10, height: 10), uti: PasteboardTypes.png))!
        let img = store.insertOrBump(image, sourceBundleID: nil, sourceAppName: "Chrome")
        store.togglePin(img.id)

        XCTAssertEqual(ClipSearch.filter(store.items, query: "cafe", filter: .all).count, 1)     // accent-insensitive
        XCTAssertEqual(ClipSearch.filter(store.items, query: "СВЯТ", filter: .all).count, 1)     // Cyrillic, case-insensitive
        XCTAssertEqual(ClipSearch.filter(store.items, query: "safari lait", filter: .all).count, 1)
        XCTAssertEqual(ClipSearch.filter(store.items, query: "", filter: .images).map(\.id), [img.id])
        XCTAssertEqual(ClipSearch.filter(store.items, query: "", filter: .text).count, 2)
        XCTAssertEqual(ClipSearch.filter(store.items, query: "", filter: .pinned).map(\.id), [img.id])
        XCTAssertEqual(ClipSearch.filter(store.items, query: "image", filter: .all).map(\.id), [img.id])
    }
}
