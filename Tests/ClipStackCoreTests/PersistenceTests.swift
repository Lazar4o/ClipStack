import XCTest
@testable import ClipStackCore

final class PersistenceTests: XCTestCase {
    func testSaveLoadRoundTrip() {
        let dir = makeTempDir()
        let store = makeStore(limit: 10, dir: dir)
        let a = store.insertOrBump(textClip("alpha"), sourceBundleID: "com.apple.TextEdit", sourceAppName: "TextEdit")
        store.togglePin(a.id)
        let image = ClipProcessing.process(.image(data: TestImages.make(width: 64, height: 48, type: .tiff), uti: PasteboardTypes.tiff))!
        let img = store.insertOrBump(image, sourceBundleID: nil, sourceAppName: nil)
        store.flush()

        let reloaded = makeStore(limit: 10, dir: dir)
        reloaded.load()
        XCTAssertEqual(reloaded.items, store.items)
        XCTAssertEqual(reloaded.persistence.loadText(a.id), "alpha")
        XCTAssertNotNil(reloaded.persistence.loadPNG(img.id))
        XCTAssertNotNil(reloaded.persistence.loadThumbnail(img.id))
        XCTAssertEqual(reloaded.items.last?.isPinned, true)
    }

    func testCorruptIndexIsMovedAsideAndStartsEmpty() throws {
        let dir = makeTempDir()
        let persistence = HistoryPersistence(baseURL: dir, saveDelay: 0)
        try Data("{ not json".utf8).write(to: persistence.indexURL)
        XCTAssertEqual(persistence.loadIndex(), [])
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("history.corrupt-") }, "\(files)")
        XCTAssertFalse(files.contains("history.json"))
    }

    func testSweepDropsMissingBlobsAndDeletesOrphans() throws {
        let dir = makeTempDir()
        let store = makeStore(limit: 10, dir: dir)
        let keep = store.insertOrBump(textClip("keep"), sourceBundleID: nil, sourceAppName: nil)
        let broken = store.insertOrBump(textClip("broken"), sourceBundleID: nil, sourceAppName: nil)
        store.flush()
        let p = store.persistence
        try FileManager.default.removeItem(at: p.blobURL(broken.id, .text))      // simulate a lost blob
        let orphan = p.blobsURL.appendingPathComponent(UUID().uuidString + ".png")
        try Data([1, 2, 3]).write(to: orphan)                                    // simulate a crash leftover

        let reloaded = makeStore(limit: 10, dir: dir)
        reloaded.load()
        XCTAssertEqual(reloaded.items.map(\.id), [keep.id])
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
        reloaded.flush()
        XCTAssertEqual(reloaded.persistence.loadIndex().map(\.id), [keep.id])     // cleanup was saved
    }

    func testLoadEnforcesLimit() {
        let dir = makeTempDir()
        let store = makeStore(limit: 20, dir: dir)
        for i in 1...15 { store.insertOrBump(textClip("i\(i)"), sourceBundleID: nil, sourceAppName: nil) }
        store.flush()
        let reloaded = makeStore(limit: 10, dir: dir)
        reloaded.load()
        XCTAssertEqual(reloaded.items.count, 10)
        XCTAssertEqual(reloaded.items.first?.previewText, "i15")
    }
}
