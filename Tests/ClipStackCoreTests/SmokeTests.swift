import XCTest
@testable import ClipStackCore

final class SmokeTests: XCTestCase {
    func testClipItemCodableRoundTrip() throws {
        let item = ClipItem(kind: .text, createdAt: Date(), lastUsedAt: Date(), contentHash: "t:abc", byteSize: 3)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ClipItem.self, from: data)
        XCTAssertEqual(decoded, item)
    }
}
