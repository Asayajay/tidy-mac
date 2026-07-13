import Foundation

/// How `Organizer.run` should behave. Dry run and live are mutually exclusive code
/// paths on purpose -- see the doc comment on `FileOperationsPerforming`.
public enum OrganizeMode {
    case dryRun
    case live(operations: FileOperationsPerforming, logStore: MoveLogStore)
}

public struct OrganizationResult {
    public let plan: OrganizationPlan
    /// Set only when `mode` was `.live`. Always `nil` for a dry run.
    public let batch: MoveBatch?
}

public final class Organizer {
    public var rules: [FileRule]
    public var scanSettings: ScanSettings
    private let lockChecker: FileLockChecking

    public init(
        rules: [FileRule],
        scanSettings: ScanSettings = ScanSettings(),
        lockChecker: FileLockChecking = PosixFileLockChecker()
    ) {
        self.rules = rules
        self.scanSettings = scanSettings
        self.lockChecker = lockChecker
    }

    /// Computes what would happen, reading directory/file metadata but never writing
    /// anything. Safe to call as often as you like, including repeatedly for a live UI.
    public func makePlan(for root: URL) throws -> OrganizationPlan {
        let scanner = Scanner(settings: scanSettings)
        let engine = RuleEngine()
        let entries = try scanner.scan(root: root)

        var moves: [PlannedMove] = []
        var skipped: [SkippedItem] = []
        var reservedDestinationPaths = Set<String>()

        for entry in entries {
            switch entry {
            case .skipped(let url, let reason):
                skipped.append(SkippedItem(source: url, reason: reason))

            case .candidate(let candidate):
                if lockChecker.isLocked(candidate.url) {
                    skipped.append(SkippedItem(source: candidate.url, reason: .fileInUse))
                    continue
                }
                guard let rule = engine.firstMatchingRule(for: candidate, in: rules) else {
                    skipped.append(SkippedItem(source: candidate.url, reason: .noRuleMatched))
                    continue
                }
                let destinationDirectory = root.appendingPathComponent(rule.destinationSubpath, isDirectory: true)
                let preferred = destinationDirectory.appendingPathComponent(candidate.filename)
                let destination = Self.resolveNonCollidingPath(preferred: preferred, alsoReserved: reservedDestinationPaths)
                reservedDestinationPaths.insert(destination.path)
                moves.append(PlannedMove(source: candidate.url, destination: destination, ruleName: rule.name))
            }
        }

        return OrganizationPlan(moves: moves, skipped: skipped)
    }

    /// Finds a destination path that collides with neither what's already on disk nor
    /// another file already planned to move into the same folder in this batch.
    /// Never overwrites: `Existing.pdf` becomes `Existing (1).pdf`, not a clobber.
    static func resolveNonCollidingPath(preferred: URL, alsoReserved: Set<String>) -> URL {
        var candidate = preferred
        var counter = 1
        let ext = preferred.pathExtension
        let baseName = preferred.deletingPathExtension().lastPathComponent
        let directory = preferred.deletingLastPathComponent()

        while FileManager.default.fileExists(atPath: candidate.path) || alsoReserved.contains(candidate.path) {
            let newName = ext.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }

    /// Performs the moves in `plan` and logs the resulting batch. Only ever reached from
    /// `run(for:mode:)` when `mode` is `.live` -- never call this to implement dry run.
    @discardableResult
    private func execute(plan: OrganizationPlan, operations: FileOperationsPerforming, logStore: MoveLogStore) throws -> MoveBatch {
        var entries: [MoveLogEntry] = []
        var createdDirectories: [String] = []
        for move in plan.moves {
            let newlyCreated = try operations.createDirectoryIfNeeded(at: move.destination.deletingLastPathComponent())
            createdDirectories.append(contentsOf: newlyCreated.map(\.path))
            try operations.moveItem(from: move.source, to: move.destination)
            entries.append(MoveLogEntry(
                sourcePath: move.source.path,
                destinationPath: move.destination.path,
                ruleName: move.ruleName,
                timestamp: Date()
            ))
        }
        let batch = MoveBatch(timestamp: Date(), entries: entries, createdDirectories: createdDirectories)
        try logStore.append(batch)
        return batch
    }

    /// The single entry point the app should call. Dry run computes and returns the plan
    /// only. Live computes the plan and then executes it, logging every move.
    public func run(for root: URL, mode: OrganizeMode) throws -> OrganizationResult {
        let plan = try makePlan(for: root)
        switch mode {
        case .dryRun:
            return OrganizationResult(plan: plan, batch: nil)
        case .live(let operations, let logStore):
            let batch = try execute(plan: plan, operations: operations, logStore: logStore)
            return OrganizationResult(plan: plan, batch: batch)
        }
    }
}
