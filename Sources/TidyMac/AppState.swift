import Foundation
import Combine
import TidyMacCore

/// Central app state: owns settings, the move log, and the trigger (watcher/timer)
/// that decides when a folder gets organized. Every actual organize call funnels
/// through `Organizer.run(for:mode:)`, so the dry-run guarantee established in
/// TidyMacCore holds no matter which UI action or trigger kicked it off.
@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            SettingsStore.save(settings)
            if settings.triggerMode != oldValue.triggerMode || settings.watchedFolders != oldValue.watchedFolders {
                setupTrigger()
            }
        }
    }
    @Published private(set) var lastPlans: [UUID: OrganizationPlan] = [:]
    @Published private(set) var lastFailures: [UUID: [FailedMove]] = [:]
    @Published private(set) var batches: [MoveBatch] = []
    @Published var statusMessage: String = ""
    /// Set by "Organize Now" to open the preview window for a specific folder. A
    /// separate Window scene, not a .sheet attached to the menu bar's own popover --
    /// presenting a sheet from inside a MenuBarExtra(.window) popover corrupted the
    /// popover's own layout (content clipped on both edges), confirmed on a real machine.
    @Published var folderPendingReview: WatchedFolder?
    /// Set by "Clean Up Empty Folders" to open the review sheet for a specific folder.
    @Published var folderForEmptyFolderReview: WatchedFolder?
    @Published private(set) var emptyFolderCandidates: [URL] = []

    private let logStore: MoveLogStore
    private var watcher: DirectoryWatcher?
    private var scheduledTimer: Timer?

    init() {
        let loaded = SettingsStore.load()
        self.settings = loaded
        self.logStore = MoveLogStore(fileURL: SettingsStore.moveLogURL)
        refreshBatches()
        setupTrigger()
    }

    // MARK: - Folders

    func addFolder(url: URL) {
        guard !settings.watchedFolders.contains(where: { $0.path == url.path }) else { return }
        settings.watchedFolders.append(WatchedFolder(path: url.path))
    }

    func removeFolder(id: UUID) {
        settings.watchedFolders.removeAll { $0.id == id }
        lastPlans[id] = nil
        lastFailures[id] = nil
    }

    // MARK: - Organizing

    private func organizer(for folder: WatchedFolder) -> Organizer {
        Organizer(rules: settings.rules, scanSettings: folder.scanSettings)
    }

    /// Computes and stores a preview without moving anything. Used for the manual
    /// "Organize Now" review step and for silent previews while in dry-run mode.
    @discardableResult
    func preview(folder: WatchedFolder) -> OrganizationPlan? {
        guard let plan = try? organizer(for: folder).makePlan(for: folder.url) else {
            statusMessage = "Couldn't read \(folder.displayName)"
            return nil
        }
        lastPlans[folder.id] = plan
        return plan
    }

    /// Actually moves the files in the most recently computed plan for this folder.
    /// This is the only place in the app that runs `.live` mode -- everything else
    /// (previews, dry-run-mode triggers) only ever calls `preview`.
    func approveAndMove(folder: WatchedFolder) {
        let operations = LiveFileOperations()
        guard let result = try? organizer(for: folder).run(for: folder.url, mode: .live(operations: operations, logStore: logStore)) else {
            statusMessage = "Failed to organize \(folder.displayName)"
            return
        }
        lastPlans[folder.id] = result.plan
        lastFailures[folder.id] = result.failedMoves
        let moved = result.batch?.entries.count ?? 0
        statusMessage = moved > 0
            ? "Moved \(moved) file\(moved == 1 ? "" : "s") in \(folder.displayName)"
            : "Nothing to organize in \(folder.displayName)"
        refreshBatches()
    }

    /// Called by a trigger (file-system change or schedule), never by a direct user
    /// click. Respects the global mode: dry run only ever refreshes the preview,
    /// auto-organize actually moves files.
    func runTriggered(folder: WatchedFolder) {
        switch settings.mode {
        case .dryRun:
            preview(folder: folder)
        case .auto:
            approveAndMove(folder: folder)
        }
    }

    func runTriggeredForAllEnabledFolders() {
        for folder in settings.watchedFolders where folder.isEnabled {
            runTriggered(folder: folder)
        }
    }

    // MARK: - Undo

    func undoLastBatch() {
        let undoer = MoveUndoer(logStore: logStore, operations: LiveFileOperations())
        do {
            let outcome = try undoer.undoLastBatch()
            statusMessage = outcome.failures.isEmpty
                ? "Undid \(outcome.restoredCount) move\(outcome.restoredCount == 1 ? "" : "s")"
                : "Undid \(outcome.restoredCount), \(outcome.failures.count) couldn't be restored"
        } catch {
            statusMessage = "Nothing to undo"
        }
        refreshBatches()
    }

    func undo(batchID: UUID) {
        let undoer = MoveUndoer(logStore: logStore, operations: LiveFileOperations())
        do {
            let outcome = try undoer.undo(batchID: batchID)
            statusMessage = outcome.failures.isEmpty
                ? "Undid \(outcome.restoredCount) move\(outcome.restoredCount == 1 ? "" : "s")"
                : "Undid \(outcome.restoredCount), \(outcome.failures.count) couldn't be restored"
        } catch {
            statusMessage = "Couldn't undo that batch"
        }
        refreshBatches()
    }

    var canUndoSomething: Bool {
        batches.contains { !$0.undone }
    }

    // MARK: - Empty folder cleanup

    /// Scans and opens the review sheet. Nothing is deleted here -- same "show it,
    /// then approve it" shape as organizing.
    func previewEmptyFolders(for folder: WatchedFolder) {
        let scanner = EmptyFolderScanner()
        emptyFolderCandidates = (try? scanner.findEmptyFolders(in: folder.url)) ?? []
        folderForEmptyFolderReview = folder
    }

    /// Removes exactly the folders passed in (the ones the user left checked in the
    /// review sheet), logging the batch so it shows up in Activity and can be undone.
    func removeEmptyFolders(_ folders: [URL]) {
        let remover = EmptyFolderRemover(logStore: logStore)
        guard let result = try? remover.remove(folders, operations: LiveFileOperations()) else {
            statusMessage = "Failed to remove empty folders"
            return
        }
        statusMessage = result.skipped.isEmpty
            ? "Removed \(result.removedCount) empty folder\(result.removedCount == 1 ? "" : "s")"
            : "Removed \(result.removedCount), \(result.skipped.count) no longer empty"
        refreshBatches()
    }

    private func refreshBatches() {
        batches = logStore.loadBatches().sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Trigger setup

    private func setupTrigger() {
        watcher?.stopAll()
        watcher = nil
        scheduledTimer?.invalidate()
        scheduledTimer = nil

        switch settings.triggerMode {
        case .manualOnly:
            break

        case .onFileSystemChange:
            let urls = settings.watchedFolders.filter(\.isEnabled).map(\.url)
            let newWatcher = DirectoryWatcher { [weak self] url in
                guard let self else { return }
                if let folder = self.settings.watchedFolders.first(where: { $0.url == url }) {
                    self.runTriggered(folder: folder)
                }
            }
            newWatcher.watch(urls)
            watcher = newWatcher

        case .scheduled(let minutes):
            let interval = TimeInterval(max(minutes, 1) * 60)
            scheduledTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.runTriggeredForAllEnabledFolders()
                }
            }
        }
    }
}
