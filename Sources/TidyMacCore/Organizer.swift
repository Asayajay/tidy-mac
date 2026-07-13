import Foundation

/// How `Organizer.run` should behave. Dry run and live are mutually exclusive code
/// paths on purpose -- see the doc comment on `FileOperationsPerforming`.
public enum OrganizeMode {
    case dryRun
    case live(operations: FileOperationsPerforming, logStore: MoveLogStore)
}

public struct OrganizationResult {
    public let plan: OrganizationPlan
    /// Set only when `mode` was `.live` and at least one move succeeded. Always `nil` for
    /// a dry run, and also `nil` if every planned move failed (nothing to log or undo).
    public let batch: MoveBatch?
    /// Planned moves that were attempted in `.live` mode but failed (e.g. the source
    /// vanished, permissions changed, or something new appeared at the destination
    /// between planning and execution). Always empty for a dry run. One failure never
    /// aborts the rest of the batch, and every move that *did* succeed is still logged.
    public let failedMoves: [FailedMove]
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
                let sanitizedSubpath = Self.sanitizedRelativePath(rule.destinationSubpath)
                let destinationDirectory = root.appendingPathComponent(sanitizedSubpath, isDirectory: true)
                let preferred = destinationDirectory.appendingPathComponent(candidate.filename)
                let destination = Self.resolveNonCollidingPath(preferred: preferred, alsoReserved: reservedDestinationPaths)
                reservedDestinationPaths.insert(destination.path)
                moves.append(PlannedMove(source: candidate.url, destination: destination, ruleName: rule.name))
            }
        }

        return OrganizationPlan(moves: moves, skipped: skipped)
    }

    /// Strips ".", "..", and empty components from a rule's destination subpath so a
    /// rule -- however it was authored, typo'd, or shared -- can never move a file
    /// outside the watched folder's root. `URL.appendingPathComponent` does not resolve
    /// ".." itself; the underlying move/create calls resolve it at the OS level, so
    /// without this a destination of "../../etc" would genuinely write outside the
    /// watched folder. This is a path-traversal guard, not a formatting nicety.
    static func sanitizedRelativePath(_ subpath: String) -> String {
        subpath
            .split(separator: "/")
            .filter { $0 != ".." && $0 != "." && !$0.isEmpty }
            .joined(separator: "/")
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

    /// Performs the moves in `plan` and logs whichever ones succeeded. Only ever reached
    /// from `run(for:mode:)` when `mode` is `.live` -- never call this to implement dry run.
    ///
    /// Each move is attempted independently: one failure (a race on the destination,
    /// a permissions change, the source vanishing between plan and execute) is recorded
    /// and skipped rather than thrown, so it can never take down the moves before or
    /// after it in the same batch. Losing the log entry for a move that already
    /// happened on disk would leave that file both unlogged and un-undoable, which is
    /// worse than reporting one failure among many successes.
    private func execute(
        plan: OrganizationPlan,
        operations: FileOperationsPerforming,
        logStore: MoveLogStore
    ) throws -> (batch: MoveBatch?, failures: [FailedMove]) {
        var entries: [MoveLogEntry] = []
        var createdDirectories: [String] = []
        var failures: [FailedMove] = []

        for move in plan.moves {
            do {
                let newlyCreated = try operations.createDirectoryIfNeeded(at: move.destination.deletingLastPathComponent())
                createdDirectories.append(contentsOf: newlyCreated.map(\.path))
                try operations.moveItem(from: move.source, to: move.destination)
                entries.append(MoveLogEntry(
                    sourcePath: move.source.path,
                    destinationPath: move.destination.path,
                    ruleName: move.ruleName,
                    timestamp: Date()
                ))
            } catch {
                failures.append(FailedMove(
                    source: move.source,
                    destination: move.destination,
                    ruleName: move.ruleName,
                    errorDescription: error.localizedDescription
                ))
            }
        }

        guard !entries.isEmpty else {
            return (nil, failures)
        }
        let batch = MoveBatch(timestamp: Date(), entries: entries, createdDirectories: createdDirectories)
        try logStore.append(batch)
        return (batch, failures)
    }

    /// The single entry point the app should call. Dry run computes and returns the plan
    /// only. Live computes the plan and then executes it, logging every move that succeeds.
    public func run(for root: URL, mode: OrganizeMode) throws -> OrganizationResult {
        let plan = try makePlan(for: root)
        switch mode {
        case .dryRun:
            return OrganizationResult(plan: plan, batch: nil, failedMoves: [])
        case .live(let operations, let logStore):
            let (batch, failures) = try execute(plan: plan, operations: operations, logStore: logStore)
            return OrganizationResult(plan: plan, batch: batch, failedMoves: failures)
        }
    }
}
