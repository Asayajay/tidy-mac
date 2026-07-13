import Foundation
#if canImport(Darwin)
import Darwin
#endif

enum TestSupport {
    /// `URL.resolvingSymlinksInPath()` is unreliable for paths under the per-user temp
    /// directory (it leaves `/var/folders/...` as-is instead of resolving to
    /// `/private/var/folders/...`), so real `realpath(3)` is used instead. Without this,
    /// URLs built from `FileManager.default.temporaryDirectory` don't compare equal to the
    /// URLs `contentsOfDirectory` returns, which resolves the real path.
    private static func resolved(_ url: URL) -> URL {
        var buffer = [Int8](repeating: 0, count: Int(PATH_MAX))
        guard realpath(url.path, &buffer) != nil else { return url }
        return URL(fileURLWithPath: String(cString: buffer), isDirectory: true)
    }

    static func makeTempDirectory(function: String = #function) throws -> URL {
        let base = FileManager.default.temporaryDirectory
        let unique = "TidyMacTests-\(function)-\(UUID().uuidString)"
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        let dir = base.appendingPathComponent(unique, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return resolved(dir)
    }

    @discardableResult
    static func writeFile(named name: String, contents: String = "hello", in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// A recursive fingerprint of a directory tree: relative path -> content hash (or
    /// symlink target). Used to prove dry-run mode leaves a directory byte-for-byte
    /// identical, not just "reports correctly."
    static func fingerprint(of root: URL) throws -> [String: String] {
        var result: [String: String] = [:]
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey],
            options: []
        ) else { return result }

        for case let url as URL in enumerator {
            let relativePath = String(url.path.dropFirst(root.path.count))
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            if values.isSymbolicLink == true {
                let target = try fm.destinationOfSymbolicLink(atPath: url.path)
                result[relativePath] = "symlink->\(target)"
            } else if values.isDirectory == true {
                result[relativePath] = "dir"
            } else {
                let data = try Data(contentsOf: url)
                result[relativePath] = "file:\(data.base64EncodedString())"
            }
        }
        return result
    }
}
