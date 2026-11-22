import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import ClipStackCore

/// In-memory pasteboard. Tests must never touch NSPasteboard.general (it would wipe the user's clipboard).
struct FakePasteboard: PasteboardReading {
    var strings: [String: String] = [:]
    var datas: [String: Data] = [:]
    var markerTypes: [String] = []

    var availableTypes: [String] { Array(Set(strings.keys).union(datas.keys).union(markerTypes)) }
    func readString(type: String) -> String? { strings[type] }
    func readData(type: String) -> Data? { datas[type] ?? strings[type].map { Data($0.utf8) } }
}

enum TestImages {
    /// Solid-color image encoded as `type` (PNG, TIFF…).
    static func make(width: Int, height: Int, type: UTType = .png) -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = context.makeImage()!
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        precondition(CGImageDestinationFinalize(destination))
        return output as Data
    }
}

func makeTempDir() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClipStackTests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func textClip(_ text: String, rtf: Data? = nil) -> ProcessedClip {
    ClipProcessing.process(.text(plain: text, rtf: rtf, html: nil))!
}

/// Store on a temp dir with a deterministic clock (+1 s per call).
func makeStore(limit: Int, dir: URL = makeTempDir()) -> HistoryStore {
    let store = HistoryStore(persistence: HistoryPersistence(baseURL: dir, saveDelay: 0), limit: limit)
    var clock = Date(timeIntervalSince1970: 1_000_000)
    store.now = {
        clock = clock.addingTimeInterval(1)
        return clock
    }
    return store
}
