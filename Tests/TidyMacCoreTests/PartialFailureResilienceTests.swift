import XCTest
@testable import TidyMacCore

/// Wraps real file operations but forces one specific source path to fail, so a mid-batch
/// failure can be reproduced deterministically instead of relying on a real race condition.
private final class FlakyFileOperations: FileOperationsPerforming {
    private let live = LiveFileOperations()
    let failingSourcePath: String

    init(failingSourcePath: String) {
        self.failingSourcePath = failingSourcePath
    }

    func createDirectoryIfNeeded(at url: URL) throws -> [URL] {
        try live.createDirectoryIfNeeded(at: url)
    }

    func moveItem(from: URL, to: URL) throws {
        if from.path == failingSourcePath {
            throw CocoaError(.fileWriteUnknown)
        }
        try live.moveItem(from: from, to: to)
    }

    func fileExists(at url: URL) -> Bool {
        live.fileExists(at: url)
    }

    func isRegularFile(at url: URL) -> Bool {
        live.isRegularFile(at: url)
    }

    func removeDirectoryIfEmpty(at url: URL) -> Bool {
        live.removeDirectoryIfEmpty(at: url)
    }

    func removeIfEmptyIgnoringDSStore(at url: URL) -> Bool {
        live.removeIfEmptyIgnoringDSStore(at: url)
    }
}

/// This is the fix for a real bug found in the second safety review: `execute` used to
/// let one `moveItem` failure throw out of the whole loop, which meant any moves that had
/// already succeeded before it never reached `logStore.append`. Those files would already
/// be sitting at their new location on disk with no log entry and therefore no way to
/// undo them. Every test here asserts that a failure in the middle of a batch never
/// costs the moves around it their log entry.
final class PartialFailureResilienceTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestSupport.makeTempDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testOneFailingMoveDoesNotPreventEarlierMovesFromBeingLogged() throws {
        let pdf = try TestSupport.writeFile(named: "aaa-taxes.pdf", in: tempDir)
        let failingScreenshot = try TestSupport.writeFile(named: "bbb-Screenshot 2024-01-01 at 3.14.15 PM.png", in: tempDir)
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let organizer = Organizer(rules: DefaultRules.all)
        let operations = FlakyFileOperations(failingSourcePath: failingScreenshot.path)

        let result = try organizer.run(for: tempDir, mode: .live(operations: operations, logStore: logStore))

        // The PDF (processed before the forced failure, given alphabetical scan order)
        // must still have actually moved AND been logged.
        XCTAssertFalse(FileManager.default.fileExists(atPath: pdf.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("Documents/PDFs/aaa-taxes.pdf").path))
        XCTAssertEqual(result.batch?.entries.count, 1)
        XCTAssertEqual(logStore.loadBatches().first?.entries.count, 1)

        // The forced failure is reported, not silently dropped, and the file it
        // couldn't move stays exactly where it was.
        XCTAssertEqual(result.failedMoves.count, 1)
        XCTAssertEqual(result.failedMoves.first?.source.path, failingScreenshot.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: failingScreenshot.path))
    }

    func testSuccessfulMoveInFailedBatchCanStillBeUndone() throws {
        let pdf = try TestSupport.writeFile(named: "aaa-taxes.pdf", contents: "pdf-bytes", in: tempDir)
        let failingScreenshot = try TestSupport.writeFile(named: "bbb-Screenshot 2024-01-01 at 3.14.15 PM.png", in: tempDir)
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let organizer = Organizer(rules: DefaultRules.all)
        let operations = FlakyFileOperations(failingSourcePath: failingScreenshot.path)
        _ = try organizer.run(for: tempDir, mode: .live(operations: operations, logStore: logStore))

        let undoer = MoveUndoer(logStore: logStore, operations: LiveFileOperations())
        let outcome = try undoer.undoLastBatch()

        XCTAssertEqual(outcome.restoredCount, 1)
        XCTAssertEqual(try String(contentsOf: pdf, encoding: .utf8), "pdf-bytes")
    }

    func testBatchIsNilWhenEveryMoveFails() throws {
        let onlyFile = try TestSupport.writeFile(named: "taxes.pdf", in: tempDir)
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let organizer = Organizer(rules: DefaultRules.all)
        let operations = FlakyFileOperations(failingSourcePath: onlyFile.path)

        let result = try organizer.run(for: tempDir, mode: .live(operations: operations, logStore: logStore))

        XCTAssertNil(result.batch)
        XCTAssertEqual(result.failedMoves.count, 1)
        XCTAssertTrue(logStore.loadBatches().isEmpty, "nothing succeeded, so nothing should be logged")
    }
}
