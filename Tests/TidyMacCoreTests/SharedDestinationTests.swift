import XCTest
@testable import TidyMacCore

/// A rule's destination can be an absolute path ("~/Pictures/Screenshots" or
/// "/Users/x/Shared") instead of relative to whichever watched folder a file came
/// from -- so one rule can send matches from every watched folder to the same real
/// folder, instead of each watched folder growing its own separate same-named folder.
final class SharedDestinationTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestSupport.makeTempDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testTildeDestinationExpandsToHomeDirectory() {
        let rule = FileRule(name: "R", conditions: [], destinationSubpath: "~/SomeShared/Place")
        let resolved = Organizer.resolvedDestinationDirectory(for: rule, root: tempDir)
        let expected = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("SomeShared/Place")
        XCTAssertEqual(resolved.path, expected.path)
    }

    func testAbsoluteSlashDestinationIsUsedAsIs() {
        let rule = FileRule(name: "R", conditions: [], destinationSubpath: "/tmp/some-absolute-place")
        let resolved = Organizer.resolvedDestinationDirectory(for: rule, root: tempDir)
        XCTAssertEqual(resolved.path, "/tmp/some-absolute-place")
    }

    func testPlainRelativeDestinationStillResolvesUnderRoot() {
        let rule = FileRule(name: "R", conditions: [], destinationSubpath: "Documents/PDFs")
        let resolved = Organizer.resolvedDestinationDirectory(for: rule, root: tempDir)
        XCTAssertEqual(resolved.path, tempDir.appendingPathComponent("Documents/PDFs").path)
    }

    func testRelativeDestinationStillGetsTraversalSanitized() {
        let rule = FileRule(name: "R", conditions: [], destinationSubpath: "../../etc")
        let resolved = Organizer.resolvedDestinationDirectory(for: rule, root: tempDir)
        XCTAssertEqual(resolved.path, tempDir.appendingPathComponent("etc").path)
    }

    func testTwoWatchedFoldersShareOneAbsoluteDestination() throws {
        let folderA = try TestSupport.makeTempDirectory(function: "folderA")
        let folderB = try TestSupport.makeTempDirectory(function: "folderB")
        defer {
            try? FileManager.default.removeItem(at: folderA)
            try? FileManager.default.removeItem(at: folderB)
        }
        let sharedDestination = try TestSupport.makeTempDirectory(function: "shared")
        defer { try? FileManager.default.removeItem(at: sharedDestination) }

        let shot1 = try TestSupport.writeFile(named: "Screenshot 2024-01-01 at 1.00.00 AM.png", contents: "one", in: folderA)
        let shot2 = try TestSupport.writeFile(named: "Screenshot 2024-01-01 at 2.00.00 AM.png", contents: "two", in: folderB)

        let rule = FileRule(
            name: "Shared Screenshots",
            conditions: [MatchCondition(kind: .filenameRegex, value: "^Screen ?Shot .*")],
            destinationSubpath: sharedDestination.path
        )
        let organizer = Organizer(rules: [rule])
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))

        _ = try organizer.run(for: folderA, mode: .live(operations: LiveFileOperations(), logStore: logStore))
        _ = try organizer.run(for: folderB, mode: .live(operations: LiveFileOperations(), logStore: logStore))

        XCTAssertFalse(FileManager.default.fileExists(atPath: shot1.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: shot2.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sharedDestination.appendingPathComponent(shot1.lastPathComponent).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sharedDestination.appendingPathComponent(shot2.lastPathComponent).path))
        // Neither folder grew its own separate "Screenshots"-style subfolder.
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: folderA.path).isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: folderB.path).isEmpty)
    }
}
