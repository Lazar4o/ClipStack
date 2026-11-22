import Foundation
import os

/// Disk layout:
///   <base>/history.json                      {"version":1,"items":[ClipItem…]}  (small, never holds payloads)
///   <base>/blobs/<uuid>.txt|.rtf|.html|.png|-thumb.png
/// All file work runs on one serial queue, so a read right after a write sees the written file.
public final class HistoryPersistence: @unchecked Sendable {   // file work is serialized on `queue`; pendingSave is main-only
    public enum BlobKind: CaseIterable {
        case text, rtf, html, png, thumbnail

        var suffix: String {
            switch self {
            case .text: return ".txt"
            case .rtf: return ".rtf"
            case .html: return ".html"
            case .png: return ".png"
            case .thumbnail: return "-thumb.png"
            }
        }
    }

    private struct IndexFile: Codable {
        var version: Int
        var items: [ClipItem]
    }

    public let baseURL: URL
    public var indexURL: URL { baseURL.appendingPathComponent("history.json") }
    public var blobsURL: URL { baseURL.appendingPathComponent("blobs", isDirectory: true) }

    private let queue = DispatchQueue(label: "local.tools.ClipStack.persistence", qos: .utility)
    private var pendingSave: DispatchWorkItem?          // touched on the main thread only
    private let saveDelay: TimeInterval
    private let log = Logger(subsystem: "local.tools.ClipStack", category: "persistence")

    public init(baseURL: URL, saveDelay: TimeInterval = 0.3) {
        self.baseURL = baseURL
        self.saveDelay = saveDelay
        try? FileManager.default.createDirectory(at: blobsURL, withIntermediateDirectories: true)
    }

    /// ~/Library/Application Support/ClipStack
    public static func defaultBaseURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("ClipStack", isDirectory: true)
    }

    public func blobURL(_ id: UUID, _ kind: BlobKind) -> URL {
        blobsURL.appendingPathComponent(id.uuidString + kind.suffix)
    }

    // MARK: - Index

    /// Missing file → []. Unreadable file → renamed to history.corrupt-<time>.json and [] (never crash).
    public func loadIndex() -> [ClipItem] {
        queue.sync {
            guard let data = try? Data(contentsOf: indexURL) else { return [] }
            do {
                return try JSONDecoder().decode(IndexFile.self, from: data).items
            } catch {
                let backup = baseURL.appendingPathComponent("history.corrupt-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: indexURL, to: backup)
                log.error("history.json unreadable, moved to \(backup.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return []
            }
        }
    }

    /// Debounced save. Call from the main thread.
    public func scheduleSave(_ items: [ClipItem]) {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.writeIndexNow(items) }
        pendingSave = work
        queue.asyncAfter(deadline: .now() + saveDelay, execute: work)
    }

    /// Synchronous save of `items`; also waits for all queued blob work. Call from the main thread.
    public func flush(_ items: [ClipItem]) {
        pendingSave?.cancel()
        pendingSave = nil
        queue.sync { writeIndexNow(items) }
    }

    /// Blocks until all queued file work is done (tests).
    public func waitForPendingWork() {
        queue.sync {}
    }

    private func writeIndexNow(_ items: [ClipItem]) {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()          // default date strategy: keeps sub-second precision
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(IndexFile(version: 1, items: items))
            try data.write(to: indexURL, options: .atomic)
        } catch {
            log.error("Saving history.json failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Blobs

    public func writeBlobs(_ blobs: ClipBlobs, for id: UUID) {
        queue.async { [self] in
            try? FileManager.default.createDirectory(at: blobsURL, withIntermediateDirectories: true)
            write(blobs.text.map { Data($0.utf8) }, to: blobURL(id, .text))
            write(blobs.rtf, to: blobURL(id, .rtf))
            write(blobs.html, to: blobURL(id, .html))
            write(blobs.png, to: blobURL(id, .png))
            write(blobs.thumbnail, to: blobURL(id, .thumbnail))
        }
    }

    public func deleteBlobs(for ids: [UUID]) {
        guard !ids.isEmpty else { return }
        queue.async { [self] in
            for id in ids {
                for kind in BlobKind.allCases {
                    try? FileManager.default.removeItem(at: blobURL(id, kind))
                }
            }
        }
    }

    public func loadText(_ id: UUID) -> String? {
        readBlob(id, .text).flatMap { String(data: $0, encoding: .utf8) }
    }
    public func loadRTF(_ id: UUID) -> Data? { readBlob(id, .rtf) }
    public func loadHTML(_ id: UUID) -> Data? { readBlob(id, .html) }
    public func loadPNG(_ id: UUID) -> Data? { readBlob(id, .png) }
    public func loadThumbnail(_ id: UUID) -> Data? { readBlob(id, .thumbnail) }

    /// Drops items whose main blob is missing and deletes blob files no item references.
    public func sweep(_ items: [ClipItem]) -> [ClipItem] {
        queue.sync {
            let fm = FileManager.default
            let kept = items.filter { item in
                fm.fileExists(atPath: blobURL(item.id, item.kind == .text ? .text : .png).path)
            }
            let keptIDs = Set(kept.map { $0.id.uuidString })
            let files = (try? fm.contentsOfDirectory(atPath: blobsURL.path)) ?? []
            for name in files {
                let idPart = String(name.prefix(36))
                if !keptIDs.contains(idPart) {
                    try? fm.removeItem(at: blobsURL.appendingPathComponent(name))
                }
            }
            return kept
        }
    }

    // MARK: - Private

    private func readBlob(_ id: UUID, _ kind: BlobKind) -> Data? {
        queue.sync { try? Data(contentsOf: blobURL(id, kind)) }
    }

    private func write(_ data: Data?, to url: URL) {
        guard let data else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            log.error("Writing \(url.lastPathComponent, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
