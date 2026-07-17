import Foundation

public struct EmptyFolderRemovalResult {
    public let batch: MoveBatch?
    public let removedCount: Int
    /// Folders that were in the reviewed list but no longer qualified by the time
    /// removal actually ran (something was added to them since the preview was shown).
    public let skipped: [URL]
}

/// Removes exactly the folders it's given -- normally a list the user reviewed and
/// approved, sourced from `EmptyFolderScanner` -- and logs the batch through the same
/// `MoveLogStore` moves use, so it shows up in Activity and can be undone like anything
/// else. This is a delete, not a move, but it's always a delete of something already
/// verified empty, so undoing it (recreating an empty folder) is lossless.
public final class EmptyFolderRemover {
    private let logStore: MoveLogStore

    public init(logStore: MoveLogStore) {
        self.logStore = logStore
    }

    @discardableResult
    public func remove(_ folders: [URL], operations: FileOperationsPerforming) throws -> EmptyFolderRemovalResult {
        var removed: [String] = []
        var skipped: [URL] = []

        for folder in folders {
            if operations.removeIfEmptyIgnoringDSStore(at: folder) {
                removed.append(folder.path)
            } else {
                skipped.append(folder)
            }
        }

        guard !removed.isEmpty else {
            return EmptyFolderRemovalResult(batch: nil, removedCount: 0, skipped: skipped)
        }
        let batch = MoveBatch(timestamp: Date(), entries: [], removedEmptyFolders: removed)
        try logStore.append(batch)
        return EmptyFolderRemovalResult(batch: batch, removedCount: removed.count, skipped: skipped)
    }
}
