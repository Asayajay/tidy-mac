import Foundation

/// Finds direct subfolders of a watched root that have nothing meaningful in them, so
/// they can be offered up for removal. Never removes anything itself -- this only
/// answers "what qualifies," the same read-only role `Scanner` plays for organizing.
public struct EmptyFolderScanner {
    /// Finder's own metadata cache file. It gets regenerated automatically and isn't
    /// something anyone is storing data in, so a folder containing only this still
    /// counts as "empty" in the plain-language sense people mean.
    static let ignorableFilenames: Set<String> = [".DS_Store"]

    public init() {}

    public func findEmptyFolders(in root: URL) throws -> [URL] {
        let children = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        var result: [URL] = []
        for child in children {
            let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else { continue }
            if try Self.isEmptyForCleanup(child) {
                result.append(child)
            }
        }
        return result.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func isEmptyForCleanup(_ folder: URL) throws -> Bool {
        let contents = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        return contents.allSatisfy { ignorableFilenames.contains($0) }
    }
}
