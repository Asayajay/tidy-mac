import Foundation

/// Append-only JSON store for move batches. Every real move is written here before
/// `MoveUndoer` ever gets a chance to read it back -- undo has nothing to work from
/// except what this store already persisted to disk.
public final class MoveLogStore {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.tidymac.movelogstore")

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func loadBatches() -> [MoveBatch] {
        queue.sync { self.unsafeLoad() }
    }

    @discardableResult
    public func append(_ batch: MoveBatch) throws -> [MoveBatch] {
        try queue.sync {
            var batches = self.unsafeLoad()
            batches.append(batch)
            try self.unsafeSave(batches)
            return batches
        }
    }

    public func markUndone(batchID: UUID) throws {
        try queue.sync {
            var batches = self.unsafeLoad()
            guard let index = batches.firstIndex(where: { $0.id == batchID }) else { return }
            batches[index].undone = true
            try self.unsafeSave(batches)
        }
    }

    private func unsafeLoad() -> [MoveBatch] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let batches = try? decoder.decode([MoveBatch].self, from: data) {
            return batches
        }
        // A single malformed or unexpectedly-shaped entry shouldn't erase the rest of
        // the undo history, so fall back to decoding one batch at a time.
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.compactMap { element in
            guard let elementData = try? JSONSerialization.data(withJSONObject: element) else { return nil }
            return try? decoder.decode(MoveBatch.self, from: elementData)
        }
    }

    private func unsafeSave(_ batches: [MoveBatch]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(batches)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}
