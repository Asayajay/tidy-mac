import Foundation

/// Controls what counts as "unsorted." The safe default only looks at loose files sitting
/// directly in the watched root; opting into subfolder scanning is an explicit, separate setting.
public struct ScanSettings: Codable, Equatable {
    public var includeGenericSubfolders: Bool
    /// Subfolder names (case-insensitive, exact match) that look unsorted rather than
    /// deliberately organized, e.g. a leftover "New Folder" or "untitled folder".
    public var genericSubfolderNames: [String]

    public init(
        includeGenericSubfolders: Bool = false,
        genericSubfolderNames: [String] = ["new folder", "untitled", "untitled folder", "temp", "tmp"]
    ) {
        self.includeGenericSubfolders = includeGenericSubfolders
        self.genericSubfolderNames = genericSubfolderNames
    }

    func isGenericName(_ name: String) -> Bool {
        genericSubfolderNames.contains { name.caseInsensitiveCompare($0) == .orderedSame }
    }
}
