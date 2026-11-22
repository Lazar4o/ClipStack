import XCTest
@testable import ClipStackCore

final class ImageProcessingTests: XCTestCase {
    private let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47]

    func testTIFFIsConvertedToPNG() throws {
        let tiff = TestImages.make(width: 300, height: 200, type: .tiff)
        let result = try XCTUnwrap(ImageProcessing.normalizeToPNG(tiff, uti: PasteboardTypes.tiff))
        XCTAssertEqual(Array(result.png.prefix(4)), pngSignature)
        XCTAssertEqual(result.width, 300)
        XCTAssertEqual(result.height, 200)
    }

    func testPNGKeepsOriginalBytes() throws {
        let png = TestImages.make(width: 50, height: 60, type: .png)
        let result = try XCTUnwrap(ImageProcessing.normalizeToPNG(png, uti: PasteboardTypes.png))
        XCTAssertEqual(result.png, png)
        XCTAssertEqual(result.width, 50)
        XCTAssertEqual(result.height, 60)
    }

    func testThumbnailIsBoundedAndKeepsAspect() throws {
        let png = TestImages.make(width: 2880, height: 1800, type: .png)
        let thumb = try XCTUnwrap(ImageProcessing.thumbnailPNG(fromPNG: png, maxPixel: 720))
        let size = try XCTUnwrap(ImageProcessing.pixelSize(ofImageData: thumb))
        XCTAssertEqual(size.width, 720)
        XCTAssertEqual(size.height, 450)
    }

    func testGarbageIsRejected() {
        XCTAssertNil(ImageProcessing.normalizeToPNG(Data([0, 1, 2, 3]), uti: PasteboardTypes.png))
        XCTAssertNil(ClipProcessing.process(.image(data: Data([9, 9]), uti: PasteboardTypes.tiff)))
    }

    func testTextProcessing() throws {
        let processed = try XCTUnwrap(ClipProcessing.process(.text(plain: "\n\n  hello\tworld", rtf: nil, html: nil)))
        XCTAssertEqual(processed.previewText, "hello    world")
        XCTAssertEqual(processed.charCount, 15)          // 2 newlines + 2 spaces + "hello" + tab + "world"
        XCTAssertEqual(processed.contentHash, Hashing.textHash("\n\n  hello\tworld"))
        XCTAssertTrue(processed.contentHash.hasPrefix("t:"))
    }
}
