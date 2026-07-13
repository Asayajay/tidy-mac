import Foundation

/// Picks the first enabled rule (in order) whose conditions match a candidate.
/// Order is the whole conflict-resolution strategy: if a file could belong to more than
/// one rule, whichever rule comes first in the list wins. The UI lets users reorder rules
/// for exactly this reason.
public struct RuleEngine {
    public init() {}

    public func firstMatchingRule(for candidate: FileCandidate, in rules: [FileRule]) -> FileRule? {
        rules.first { $0.matches(candidate) }
    }
}
