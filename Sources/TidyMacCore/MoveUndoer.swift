import Foundation

public enum UndoError: Error, Equatable {
    case noBatchToUndo
    case batchNotFound
    case alreadyUndone
}

/// Why one particular entry in a batch couldn't be restored. The rest of the batch
/// still gets undone -- one conflicting file shouldn't block everything else.
public enum UndoEntryFailure: Equatable {
    case destinationMissing
    /// The logged destination path exists but is now a directory, not the file that was
    /// logged (e.g. someone created a folder with that exact name after the move ran).
    case destinationIsNotAFile
    case sourceOccupied
    case ioError(String)
}

public struct UndoOutcome {
    public let batchID: UUID
    public let restoredCount: Int
    public let failures: [(entry: MoveLogEntry, reason: UndoEntryFailure)]

    public static func == (lhs: UndoOutcome, rhs: UndoOutcome) -> Bool {
        lhs.batchID == rhs.batchID
            && lhs.restoredCount == rhs.restoredCount
            && lhs.failures.map(\.entry) == rhs.failures.map(\.entry)
            && lhs.failures.map(\.reason) == rhs.failures.map(\.reason)
    }
}

/// Reverses a previously logged batch by moving each file from its logged destination
/// back to its logged source, in reverse order. Restoring is refused, per-entry, if the
/// destination file is no longer where the log says it is, or if something new now
/// occupies the original source path -- undo never overwrites either.
public final class MoveUndoer {
    private let logStore: MoveLogStore
    private let operations: FileOperationsPerforming

    public init(logStore: MoveLogStore, operations: FileOperationsPerforming) {
        self.logStore = logStore
        self.operations = operations
    }

    @discardableResult
    public func undoLastBatch() throws -> UndoOutcome {
        let batches = logStore.loadBatches()
        guard let batch = batches.last(where: { !$0.undone }) else {
            throw UndoError.noBatchToUndo
        }
        return try undo(batch: batch)
    }

    @discardableResult
    public func undo(batchID: UUID) throws -> UndoOutcome {
        let batches = logStore.loadBatches()
        guard let batch = batches.first(where: { $0.id == batchID }) else {
            throw UndoError.batchNotFound
        }
        guard !batch.undone else {
            throw UndoError.alreadyUndone
        }
        return try undo(batch: batch)
    }

    private func undo(batch: MoveBatch) throws -> UndoOutcome {
        var restored = 0
        var failures: [(entry: MoveLogEntry, reason: UndoEntryFailure)] = []

        for entry in batch.entries.reversed() {
            let destinationURL = URL(fileURLWithPath: entry.destinationPath)
            let sourceURL = URL(fileURLWithPath: entry.sourcePath)

            guard operations.fileExists(at: destinationURL) else {
                failures.append((entry, .destinationMissing))
                continue
            }
            guard operations.isRegularFile(at: destinationURL) else {
                failures.append((entry, .destinationIsNotAFile))
                continue
            }
            guard !operations.fileExists(at: sourceURL) else {
                failures.append((entry, .sourceOccupied))
                continue
            }
            do {
                try operations.createDirectoryIfNeeded(at: sourceURL.deletingLastPathComponent())
                try operations.moveItem(from: destinationURL, to: sourceURL)
                restored += 1
            } catch {
                failures.append((entry, .ioError(error.localizedDescription)))
            }
        }

        // Clean up directories this batch created, deepest first, but only ones that are
        // now empty -- if the user added something else into "Screenshots" in the
        // meantime, it stays untouched.
        for path in batch.createdDirectories.sorted(by: { $0.count > $1.count }) {
            operations.removeDirectoryIfEmpty(at: URL(fileURLWithPath: path))
        }

        try logStore.markUndone(batchID: batch.id)
        return UndoOutcome(batchID: batch.id, restoredCount: restored, failures: failures)
    }
}
