import XCTest
@testable import TidyMacCore

/// Real round-trip tests: create real files in a real temp directory, run a real (not
/// dry-run) move batch, undo it, and check every file is back exactly where and how it
/// started -- same path, same bytes, no leftover empty folders.
final class MoveUndoerTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestSupport.makeTempDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testUndoRestoresFilesToExactOriginalPathsAndContents() throws {
        let screenshotContent = "screenshot-bytes"
        let pdfContent = "pdf-bytes"
        let screenshot = try TestSupport.writeFile(named: "Screenshot 2024-01-01 at 3.14.15 PM.png", contents: screenshotContent, in: tempDir)
        let pdf = try TestSupport.writeFile(named: "taxes.pdf", contents: pdfContent, in: tempDir)
        let originalFingerprint = try TestSupport.fingerprint(of: tempDir)

        let logURL = tempDir.appendingPathComponent("log.json")
        let logStore = MoveLogStore(fileURL: logURL)
        let organizer = Organizer(rules: DefaultRules.all)
        let liveResult = try organizer.run(for: tempDir, mode: .live(operations: LiveFileOperations(), logStore: logStore))
        XCTAssertEqual(liveResult.batch?.entries.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: screenshot.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: pdf.path))

        let undoer = MoveUndoer(logStore: logStore, operations: LiveFileOperations())
        let outcome = try undoer.undoLastBatch()

        XCTAssertEqual(outcome.restoredCount, 2)
        XCTAssertTrue(outcome.failures.isEmpty)
        XCTAssertEqual(try String(contentsOf: screenshot, encoding: .utf8), screenshotContent)
        XCTAssertEqual(try String(contentsOf: pdf, encoding: .utf8), pdfContent)

        // Exclude the log file itself (not present before the batch ran) from comparison.
        let afterUndo = try TestSupport.fingerprint(of: tempDir).filter { $0.key != "/log.json" }
        let expected = originalFingerprint.filter { $0.key != "/log.json" }
        XCTAssertEqual(afterUndo, expected, "directory tree must be byte-for-byte identical to before the move, including no leftover empty folders")
    }

    func testBatchIsMarkedUndoneAndCannotBeUndoneTwice() throws {
        try TestSupport.writeFile(named: "taxes.pdf", in: tempDir)
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let organizer = Organizer(rules: DefaultRules.all)
        _ = try organizer.run(for: tempDir, mode: .live(operations: LiveFileOperations(), logStore: logStore))

        let undoer = MoveUndoer(logStore: logStore, operations: LiveFileOperations())
        try undoer.undoLastBatch()

        XCTAssertTrue(logStore.loadBatches().first?.undone == true)
        XCTAssertThrowsError(try undoer.undoLastBatch()) { error in
            XCTAssertEqual(error as? UndoError, .noBatchToUndo)
        }
    }

    func testUndoRefusesToOverwriteANewFileAtTheOriginalLocation() throws {
        let pdf = try TestSupport.writeFile(named: "taxes.pdf", contents: "original", in: tempDir)
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let organizer = Organizer(rules: DefaultRules.all)
        _ = try organizer.run(for: tempDir, mode: .live(operations: LiveFileOperations(), logStore: logStore))
        XCTAssertFalse(FileManager.default.fileExists(atPath: pdf.path))

        try TestSupport.writeFile(named: "taxes.pdf", contents: "someone-elses-new-file", in: tempDir)

        let undoer = MoveUndoer(logStore: logStore, operations: LiveFileOperations())
        let outcome = try undoer.undoLastBatch()

        XCTAssertEqual(outcome.restoredCount, 0)
        XCTAssertEqual(outcome.failures.first?.reason, .sourceOccupied)
        XCTAssertEqual(try String(contentsOf: pdf, encoding: .utf8), "someone-elses-new-file")
    }

    func testUndoRefusesWhenLoggedDestinationNoLongerExists() throws {
        try TestSupport.writeFile(named: "taxes.pdf", in: tempDir)
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let organizer = Organizer(rules: DefaultRules.all)
        _ = try organizer.run(for: tempDir, mode: .live(operations: LiveFileOperations(), logStore: logStore))

        let destination = tempDir.appendingPathComponent("Documents/PDFs/taxes.pdf")
        try FileManager.default.removeItem(at: destination)

        let undoer = MoveUndoer(logStore: logStore, operations: LiveFileOperations())
        let outcome = try undoer.undoLastBatch()

        XCTAssertEqual(outcome.restoredCount, 0)
        XCTAssertEqual(outcome.failures.first?.reason, .destinationMissing)
    }

    func testUndoRefusesWhenDestinationWasRepurposedAsADirectory() throws {
        // Found in the second safety review: fileExists doesn't distinguish files from
        // directories, so without an explicit check, undo would move an entire directory
        // (and everything in it) back to the original file's path.
        try TestSupport.writeFile(named: "taxes.pdf", in: tempDir)
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let organizer = Organizer(rules: DefaultRules.all)
        _ = try organizer.run(for: tempDir, mode: .live(operations: LiveFileOperations(), logStore: logStore))

        let destination = tempDir.appendingPathComponent("Documents/PDFs/taxes.pdf")
        try FileManager.default.removeItem(at: destination)
        let repurposedDirectory = destination
        try FileManager.default.createDirectory(at: repurposedDirectory, withIntermediateDirectories: true)
        try TestSupport.writeFile(named: "unrelated.txt", contents: "unrelated", in: repurposedDirectory)

        let undoer = MoveUndoer(logStore: logStore, operations: LiveFileOperations())
        let outcome = try undoer.undoLastBatch()

        XCTAssertEqual(outcome.restoredCount, 0)
        XCTAssertEqual(outcome.failures.first?.reason, .destinationIsNotAFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: repurposedDirectory.appendingPathComponent("unrelated.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("taxes.pdf").path))
    }

    func testUndoingNothingThrowsNoBatchToUndo() throws {
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let undoer = MoveUndoer(logStore: logStore, operations: LiveFileOperations())
        XCTAssertThrowsError(try undoer.undoLastBatch()) { error in
            XCTAssertEqual(error as? UndoError, .noBatchToUndo)
        }
    }

    func testUndoOfPartiallyConflictedBatchStillRestoresTheRest() throws {
        try TestSupport.writeFile(named: "taxes.pdf", in: tempDir)
        try TestSupport.writeFile(named: "Screenshot 2024-01-01 at 3.14.15 PM.png", in: tempDir)
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let organizer = Organizer(rules: DefaultRules.all)
        _ = try organizer.run(for: tempDir, mode: .live(operations: LiveFileOperations(), logStore: logStore))

        // Block only the PDF's original slot; the screenshot's original slot stays free.
        try TestSupport.writeFile(named: "taxes.pdf", contents: "blocker", in: tempDir)

        let undoer = MoveUndoer(logStore: logStore, operations: LiveFileOperations())
        let outcome = try undoer.undoLastBatch()

        XCTAssertEqual(outcome.restoredCount, 1)
        XCTAssertEqual(outcome.failures.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("Screenshot 2024-01-01 at 3.14.15 PM.png").path))
    }
}
