import Foundation

/// A loose file sitting in a watched folder that is eligible to be matched against rules.
/// Directories, symlinks, and anything already inside a subfolder are filtered out before
/// they ever become a `FileCandidate` -- see `Scanner`.
public struct FileCandidate: Equatable {
    public let url: URL
    public let filename: String
    public let pathExtension: String
    public let isReadable: Bool
    public let isWritable: Bool

    public init(url: URL, filename: String, pathExtension: String, isReadable: Bool, isWritable: Bool) {
        self.url = url
        self.filename = filename
        self.pathExtension = pathExtension
        self.isReadable = isReadable
        self.isWritable = isWritable
    }
}
