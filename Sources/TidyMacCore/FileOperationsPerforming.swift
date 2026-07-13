import Foundation

/// Everything that actually touches disk goes through this seam. `Organizer.run` in
/// `.dryRun` mode never calls any method on any implementation of this protocol -- see
/// the `mode` switch in `Organizer+Run.swift`. That's the structural guarantee that dry
/// run cannot move a file: not "the code happens not to call it," but "there is no code
/// path from dry run to a mutating call at all."
public protocol FileOperationsPerforming {
    /// Creates `url` (and any missing intermediate directories) if it doesn't already
    /// exist. Returns every directory newly created, shallowest first, so callers can
    /// remember exactly what they added -- and, on undo, remove only that, never a
    /// directory that was already there before the batch ran.
    @discardableResult
    func createDirectoryIfNeeded(at url: URL) throws -> [URL]
    func moveItem(from: URL, to: URL) throws
    func fileExists(at url: URL) -> Bool
    /// True only if `url` exists and is a regular file (not a directory). Undo uses this
    /// to refuse restoring from a path that used to hold a file but now holds a
    /// directory someone created there for unrelated reasons -- `fileExists` alone can't
    /// tell files and directories apart, and moving a whole directory back in place of a
    /// single logged file would be a much bigger, more surprising change than undo should
    /// ever make.
    func isRegularFile(at url: URL) -> Bool
    /// Removes `url` only if it currently exists and is empty. Returns whether it removed it.
    @discardableResult
    func removeDirectoryIfEmpty(at url: URL) -> Bool
}

public struct LiveFileOperations: FileOperationsPerforming {
    public init() {}

    @discardableResult
    public func createDirectoryIfNeeded(at url: URL) throws -> [URL] {
        var missingAncestors: [URL] = []
        var current = url
        while !FileManager.default.fileExists(atPath: current.path) {
            missingAncestors.append(current)
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
        var created: [URL] = []
        for directory in missingAncestors.reversed() {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            created.append(directory)
        }
        return created
    }

    public func moveItem(from: URL, to: URL) throws {
        try FileManager.default.moveItem(at: from, to: to)
    }

    public func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func isRegularFile(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return false }
        return !isDirectory.boolValue
    }

    @discardableResult
    public func removeDirectoryIfEmpty(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path), contents.isEmpty else {
            return false
        }
        return (try? FileManager.default.removeItem(at: url)) != nil
    }
}
