import AppKit
import XCTest
@testable import ClipStackCore

final class ClassifierTests: XCTestCase {
    private let rules = CaptureRules()
    private let png = TestImages.make(width: 40, height: 30, type: .png)
    private let tiff = TestImages.make(width: 40, height: 30, type: .tiff)

    private func classify(_ pb: FakePasteboard, source: String? = nil, rules: CaptureRules? = nil) -> CapturedClip? {
        ClipClassifier.classify(pb, sourceBundleID: source, rules: rules ?? self.rules)
    }

    func testEmptyPasteboardIsIgnored() {
        XCTAssertNil(classify(FakePasteboard()))
    }

    func testConcealedAndTransientAreIgnored() {
        for marker in ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "com.agilebits.onepassword"] {
            let pb = FakePasteboard(strings: [PasteboardTypes.plainText: "hunter2"], markerTypes: [marker])
            XCTAssertNil(classify(pb), marker)
        }
    }

    func testIgnoredSourceAppIsIgnored() {
        let pb = FakePasteboard(strings: [PasteboardTypes.plainText: "secret"])
        XCTAssertNil(classify(pb, source: "com.apple.Passwords"))
        XCTAssertNotNil(classify(pb, source: "com.apple.Safari"))
    }

    func testFinderFileCopyWithIconIsIgnored() {
        let pb = FakePasteboard(strings: [PasteboardTypes.plainText: "report.pdf", PasteboardTypes.fileURL: "file:///tmp/report.pdf"],
                                datas: [PasteboardTypes.tiff: tiff])
        XCTAssertNil(classify(pb))
    }

    func testPlainText() {
        let pb = FakePasteboard(strings: [PasteboardTypes.plainText: "hello"])
        XCTAssertEqual(classify(pb), .text(plain: "hello", rtf: nil, html: nil))
    }

    func testPNGOnlyIsImage() {
        let pb = FakePasteboard(datas: [PasteboardTypes.png: png])
        XCTAssertEqual(classify(pb), .image(data: png, uti: PasteboardTypes.png))
    }

    func testTIFFOnlyIsImage() {
        let pb = FakePasteboard(datas: [PasteboardTypes.tiff: tiff])
        XCTAssertEqual(classify(pb), .image(data: tiff, uti: PasteboardTypes.tiff))
    }

    func testPNGPreferredOverTIFF() {
        let pb = FakePasteboard(datas: [PasteboardTypes.tiff: tiff, PasteboardTypes.png: png])
        XCTAssertEqual(classify(pb), .image(data: png, uti: PasteboardTypes.png))
    }

    func testTextWinsOverPictureOfSelection() {
        // Excel / Numbers: cell text plus a rendered picture of the cells.
        let pb = FakePasteboard(strings: [PasteboardTypes.plainText: "A1\tB1\n1\t2"], datas: [PasteboardTypes.tiff: tiff])
        guard case .text(let plain, _, _) = classify(pb) else { return XCTFail("expected text") }
        XCTAssertEqual(plain, "A1\tB1\n1\t2")
    }

    func testLoneURLNextToImageIsImage() {
        let pb = FakePasteboard(strings: [PasteboardTypes.plainText: "https://example.com/cat.png"], datas: [PasteboardTypes.tiff: tiff])
        XCTAssertEqual(classify(pb), .image(data: tiff, uti: PasteboardTypes.tiff))
    }

    func testWhitespaceOnlyIsIgnored() {
        XCTAssertNil(classify(FakePasteboard(strings: [PasteboardTypes.plainText: "  \n\t "])))
    }

    func testOversizedTextIsIgnored() {
        let small = CaptureRules(maxTextBytes: 10)
        XCTAssertNil(classify(FakePasteboard(strings: [PasteboardTypes.plainText: String(repeating: "x", count: 11)]), rules: small))
        XCTAssertNotNil(classify(FakePasteboard(strings: [PasteboardTypes.plainText: "short"]), rules: small))
    }

    func testCaptureToggles() {
        XCTAssertNil(classify(FakePasteboard(datas: [PasteboardTypes.png: png]), rules: CaptureRules(captureImages: false)))
        XCTAssertNil(classify(FakePasteboard(strings: [PasteboardTypes.plainText: "hi"]), rules: CaptureRules(captureText: false)))
    }

    func testRichFlavoursKeptAndOversizedDropped() {
        let rtf = Data("{\\rtf1 hi}".utf8)
        let html = Data("<b>hi</b>".utf8)
        let pb = FakePasteboard(strings: [PasteboardTypes.plainText: "hi"], datas: [PasteboardTypes.rtf: rtf, PasteboardTypes.html: html])
        XCTAssertEqual(classify(pb), .text(plain: "hi", rtf: rtf, html: html))
        XCTAssertEqual(classify(pb, rules: CaptureRules(maxRichBytes: 9)), .text(plain: "hi", rtf: nil, html: html))
    }

    func testSingleURLDetection() {
        XCTAssertTrue(ClipClassifier.isSingleURL(" https://a.b/c \n"))
        XCTAssertFalse(ClipClassifier.isSingleURL("see https://a.b"))
        XCTAssertFalse(ClipClassifier.isSingleURL("hello"))
    }

    /// Exercises the real NSPasteboard conformance on a private, uniquely named pasteboard.
    func testRealNamedPasteboard() {
        let pb = NSPasteboard(name: NSPasteboard.Name("ClipStackTests-\(UUID().uuidString)"))
        defer { pb.releaseGlobally() }

        pb.clearContents()
        pb.setString("from a real pasteboard", forType: .string)
        XCTAssertEqual(ClipClassifier.classify(pb, sourceBundleID: nil, rules: rules),
                       .text(plain: "from a real pasteboard", rtf: nil, html: nil))

        pb.clearContents()
        pb.setData(png, forType: .png)
        XCTAssertEqual(ClipClassifier.classify(pb, sourceBundleID: nil, rules: rules),
                       .image(data: png, uti: PasteboardTypes.png))

        pb.clearContents()
        let item = NSPasteboardItem()
        item.setString("password", forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        pb.writeObjects([item])
        XCTAssertNil(ClipClassifier.classify(pb, sourceBundleID: nil, rules: rules))
    }
}
