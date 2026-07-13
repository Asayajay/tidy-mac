import XCTest
@testable import TidyMacCore
#if canImport(Darwin)
import Darwin
#endif

final class LiveMoveAndLoggingTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestSupport.makeTempDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testLiveRunMovesFilesToTheirRuleDestination() throws {
        let screenshot = try TestSupport.writeFile(named: "Screenshot 2024-01-01 at 3.14.15 PM.png", in: tempDir)
        let pdf = try TestSupport.writeFile(named: "taxes.pdf", in: tempDir)
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let organizer = Organizer(rules: DefaultRules.all)

        let result = try organizer.run(for: tempDir, mode: .live(operations: LiveFileOperations(), logStore: logStore))

        XCTAssertFalse(FileManager.default.fileExists(atPath: screenshot.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("Screenshots/Screenshot 2024-01-01 at 3.14.15 PM.png").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: pdf.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("Documents/PDFs/taxes.pdf").path))
        XCTAssertNotNil(result.batch)
    }

    func testEveryMoveIsLoggedBeforeAnyoneCanRelyOnTheLog() throws {
        try TestSupport.writeFile(named: "Screenshot 2024-01-01 at 3.14.15 PM.png", in: tempDir)
        try TestSupport.writeFile(named: "taxes.pdf", in: tempDir)
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let organizer = Organizer(rules: DefaultRules.all)

        let result = try organizer.run(for: tempDir, mode: .live(operations: LiveFileOperations(), logStore: logStore))

        let persisted = logStore.loadBatches()
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted.first?.id, result.batch?.id)
        XCTAssertEqual(persisted.first?.entries.count, 2)
        for entry in persisted.first?.entries ?? [] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: entry.sourcePath), "logged source should no longer exist")
            XCTAssertTrue(FileManager.default.fileExists(atPath: entry.destinationPath), "logged destination should exist")
        }
    }

    func testExistingDestinationFileIsNeverOverwritten() throws {
        let pdfDir = tempDir.appendingPathComponent("Documents/PDFs", isDirectory: true)
        try FileManager.default.createDirectory(at: pdfDir, withIntermediateDirectories: true)
        let existing = try TestSupport.writeFile(named: "taxes.pdf", contents: "existing-content", in: pdfDir)
        let incoming = try TestSupport.writeFile(named: "taxes.pdf", contents: "incoming-content", in: tempDir)

        let organizer = Organizer(rules: DefaultRules.all)
        let plan = try organizer.makePlan(for: tempDir)
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        _ = try organizer.run(for: tempDir, mode: .live(operations: LiveFileOperations(), logStore: logStore))

        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "existing-content")
        XCTAssertEqual(try String(contentsOf: pdfDir.appendingPathComponent("taxes (1).pdf"), encoding: .utf8), "incoming-content")
        XCTAssertEqual(plan.moves.first?.destination.lastPathComponent, "taxes (1).pdf")
        XCTAssertFalse(FileManager.default.fileExists(atPath: incoming.path))
    }

    func testTwoNewFilesWithSameNameInSameBatchBothGetUniqueDestinations() throws {
        // Two files that both resolve to the same rule/destination folder shouldn't
        // collide with each other even though neither exists at the destination yet.
        let subA = tempDir.appendingPathComponent("A", isDirectory: true)
        let subB = tempDir.appendingPathComponent("B", isDirectory: true)
        // Can't have two files with the same name in the same root directory, so
        // simulate via two separate organizer runs into the same destination instead.
        try FileManager.default.createDirectory(at: subA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: subB, withIntermediateDirectories: true)
        try TestSupport.writeFile(named: "taxes.pdf", contents: "first", in: subA)
        try TestSupport.writeFile(named: "taxes.pdf", contents: "second", in: subB)

        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let organizer = Organizer(rules: DefaultRules.all)
        _ = try organizer.run(for: subA, mode: .live(operations: LiveFileOperations(), logStore: logStore))
        _ = try organizer.run(for: subB, mode: .live(operations: LiveFileOperations(), logStore: logStore))

        XCTAssertTrue(FileManager.default.fileExists(atPath: subA.appendingPathComponent("Documents/PDFs/taxes.pdf").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: subB.appendingPathComponent("Documents/PDFs/taxes.pdf").path))
    }

    func testFileInUseIsSkippedNotMoved() throws {
        let busy = try TestSupport.writeFile(named: "busy.pdf", in: tempDir)
        let fd = open(busy.path, O_RDONLY)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { close(fd) }
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), 0)

        let organizer = Organizer(rules: DefaultRules.all)
        let plan = try organizer.makePlan(for: tempDir)

        XCTAssertTrue(plan.moves.isEmpty)
        XCTAssertEqual(plan.skipped.first?.reason, .fileInUse)
        XCTAssertTrue(FileManager.default.fileExists(atPath: busy.path))
    }
}
