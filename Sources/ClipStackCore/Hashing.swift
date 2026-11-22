import CryptoKit
import Foundation

public enum Hashing {
    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func textHash(_ text: String) -> String { "t:" + sha256Hex(Data(text.utf8)) }

    /// Hash of the raw pasteboard bytes (cheaper than normalizing first).
    public static func imageHash(_ data: Data) -> String { "i:" + sha256Hex(data) }
}
