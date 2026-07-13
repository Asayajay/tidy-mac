import Foundation

public struct PlannedMove: Equatable {
    public let source: URL
    public let destination: URL
    public let ruleName: String
}

public struct SkippedItem: Equatable {
    public let source: URL
    public let reason: SkipReason
}

/// A move that was planned but failed when actually attempted in live mode.
public struct FailedMove: Equatable {
    public let source: URL
    public let destination: URL
    public let ruleName: String
    public let errorDescription: String
}

/// What `Organizer.makePlan` would do, computed without any filesystem mutation.
/// This is the object dry-run mode shows the user; live mode executes exactly this plan.
public struct OrganizationPlan: Equatable {
    public let moves: [PlannedMove]
    public let skipped: [SkippedItem]
}
