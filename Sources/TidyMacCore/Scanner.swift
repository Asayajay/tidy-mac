import Foundation

/// The result of classifying one entry found while scanning a watched folder.
public enum ScannedEntry: Equatable {
    case candidate(FileCandidate)
    case skipped(URL, SkipReason)
}

/// Lists the contents of a watched folder and classifies each entry, without ever
/// matching against rules or touching disk beyond reading directory metadata.
///
/// By default only direct children of the root are considered -- a file inside a
/// subfolder is a strong signal the user already organized it on purpose, so it's left
/// alone. Recursing into a subfolder at all is an explicit opt-in (`ScanSettings`), and
/// even then only one level deep, into folders whose names look unsorted (e.g. "New
/// Folder"), never into folders the user gave a real name to.
public struct Scanner {
    public var settings: ScanSettings

    public init(settings: ScanSettings = ScanSettings()) {
        self.settings = settings
    }

    private static let resourceKeys: [URLResourceKey] = [
        .isDirectoryKey, .isSymbolicLinkKey, .isReadableKey, .isWritableKey
    ]

    public func scan(root: URL) throws -> [ScannedEntry] {
        let children = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: Self.resourceKeys,
            options: [.skipsHiddenFiles]
        )
        var results: [ScannedEntry] = []
        for url in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            results.append(contentsOf: try evaluate(url: url, atTopLevel: true))
        }
        return results
    }

    private func evaluate(url: URL, atTopLevel: Bool) throws -> [ScannedEntry] {
        let values = try url.resourceValues(forKeys: Set(Self.resourceKeys))

        if values.isSymbolicLink == true {
            return [.skipped(url, .isSymlink)]
        }

        if values.isDirectory == true {
            if atTopLevel && settings.includeGenericSubfolders && settings.isGenericName(url.lastPathComponent) {
                let subChildren = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: Self.resourceKeys,
                    options: [.skipsHiddenFiles]
                )
                var nested: [ScannedEntry] = []
                for child in subChildren.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                    nested.append(contentsOf: try evaluate(url: child, atTopLevel: false))
                }
                return nested
            }
            return [.skipped(url, .isSubfolder)]
        }

        guard values.isReadable ?? true else {
            return [.skipped(url, .permissionDenied)]
        }

        let candidate = FileCandidate(
            url: url,
            filename: url.lastPathComponent,
            pathExtension: url.pathExtension,
            isReadable: values.isReadable ?? true,
            isWritable: values.isWritable ?? true
        )
        return [.candidate(candidate)]
    }
}
