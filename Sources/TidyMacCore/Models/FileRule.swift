import Foundation

/// A user-editable rule: if a file satisfies its conditions, it belongs in `destinationSubpath`.
/// Rules are evaluated in array order and the first enabled match wins, so order matters --
/// e.g. "Screenshots" must be checked before the generic "Images" rule, since a screenshot
/// is also a PNG.
public struct FileRule: Codable, Equatable, Identifiable {
    public enum ConditionLogic: String, Codable {
        case any
        case all
    }

    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    public var conditions: [MatchCondition]
    public var conditionLogic: ConditionLogic
    /// Path relative to the watched folder's root, e.g. "Screenshots" or "Documents/PDFs".
    public var destinationSubpath: String

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        conditions: [MatchCondition],
        conditionLogic: ConditionLogic = .any,
        destinationSubpath: String
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.conditions = conditions
        self.conditionLogic = conditionLogic
        self.destinationSubpath = destinationSubpath
    }

    public func matches(_ candidate: FileCandidate) -> Bool {
        guard isEnabled, !conditions.isEmpty else { return false }
        switch conditionLogic {
        case .any:
            return conditions.contains { $0.matches(candidate) }
        case .all:
            return conditions.allSatisfy { $0.matches(candidate) }
        }
    }
}
