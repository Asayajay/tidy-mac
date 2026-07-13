import Foundation

/// A single testable condition used to decide whether a file matches a rule.
/// Rules combine one or more of these with `FileRule.ConditionLogic`.
public struct MatchCondition: Codable, Equatable, Identifiable {
    public enum Kind: String, Codable, CaseIterable {
        case fileExtension
        case filenameContains
        case filenamePrefix
        case filenameRegex
    }

    public var id: UUID
    public var kind: Kind
    /// Meaning depends on `kind`: an extension without the dot, a literal substring,
    /// a literal prefix, or an NSRegularExpression pattern.
    public var value: String

    public init(id: UUID = UUID(), kind: Kind, value: String) {
        self.id = id
        self.kind = kind
        self.value = value
    }

    public func matches(_ candidate: FileCandidate) -> Bool {
        switch kind {
        case .fileExtension:
            let normalized = value.hasPrefix(".") ? String(value.dropFirst()) : value
            guard !normalized.isEmpty else { return false }
            return candidate.pathExtension.caseInsensitiveCompare(normalized) == .orderedSame
        case .filenameContains:
            guard !value.isEmpty else { return false }
            return candidate.filename.range(of: value, options: .caseInsensitive) != nil
        case .filenamePrefix:
            guard !value.isEmpty else { return false }
            return candidate.filename.range(of: value, options: [.caseInsensitive, .anchored]) != nil
        case .filenameRegex:
            guard let regex = try? NSRegularExpression(pattern: value, options: [.caseInsensitive]) else {
                return false
            }
            let range = NSRange(candidate.filename.startIndex..., in: candidate.filename)
            return regex.firstMatch(in: candidate.filename, options: [], range: range) != nil
        }
    }
}
