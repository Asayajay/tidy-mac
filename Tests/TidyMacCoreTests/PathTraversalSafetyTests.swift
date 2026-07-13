import XCTest
@testable import TidyMacCore

/// Found in the second safety review: `URL.appendingPathComponent` does not resolve
/// ".." itself, but the underlying move/create-directory calls resolve it at the OS
/// level. Without sanitizing a rule's destination, a rule with a destination of
/// "../../etc" (a typo, or a maliciously crafted custom rule someone shared) would
/// genuinely move files outside the watched folder. Every test here proves a move
/// never lands anywhere outside the root, no matter what a rule's destination says.
final class PathTraversalSafetyTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestSupport.makeTempDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSanitizerStripsParentDirectoryTraversal() {
        XCTAssertEqual(Organizer.sanitizedRelativePath("../../etc/evil"), "etc/evil")
        XCTAssertEqual(Organizer.sanitizedRelativePath("Documents/../../etc"), "Documents/etc")
        XCTAssertEqual(Organizer.sanitizedRelativePath("./Documents/./PDFs"), "Documents/PDFs")
        XCTAssertEqual(Organizer.sanitizedRelativePath("Documents/PDFs"), "Documents/PDFs")
        XCTAssertEqual(Organizer.sanitizedRelativePath(""), "")
        XCTAssertEqual(Organizer.sanitizedRelativePath("../.."), "")
    }

    func testRuleWithParentTraversalDestinationCannotEscapeTheWatchedRoot() throws {
        let outsideDir = try TestSupport.makeTempDirectory(function: "outside")
        defer { try? FileManager.default.removeItem(at: outsideDir) }

        let file = try TestSupport.writeFile(named: "evil.txt", in: tempDir)
        let maliciousRule = FileRule(
            name: "Escape attempt",
            conditions: [MatchCondition(kind: .fileExtension, value: "txt")],
            destinationSubpath: "../\(outsideDir.lastPathComponent)/escaped"
        )
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let organizer = Organizer(rules: [maliciousRule])

        _ = try organizer.run(for: tempDir, mode: .live(operations: LiveFileOperations(), logStore: logStore))

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        // The traversal components are stripped, so the file must land somewhere
        // inside tempDir, never inside the sibling "outside" directory.
        let escapedPath = outsideDir.appendingPathComponent("escaped/evil.txt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: escapedPath.path))

        let movedSomewhereInsideRoot = try FileManager.default.subpathsOfDirectory(atPath: tempDir.path)
            .contains { $0.hasSuffix("evil.txt") }
        XCTAssertTrue(movedSomewhereInsideRoot, "file must still be found somewhere inside the watched root")
    }

    func testAbsolutePathLikeDestinationStaysContainedInRoot() throws {
        let file = try TestSupport.writeFile(named: "evil.pdf", in: tempDir)
        let rule = FileRule(
            name: "Absolute-looking",
            conditions: [MatchCondition(kind: .fileExtension, value: "pdf")],
            destinationSubpath: "/etc/evil"
        )
        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let organizer = Organizer(rules: [rule])

        _ = try organizer.run(for: tempDir, mode: .live(operations: LiveFileOperations(), logStore: logStore))

        XCTAssertFalse(FileManager.default.fileExists(atPath: "/etc/evil/evil.pdf"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("etc/evil/evil.pdf").path))
        _ = file
    }
}
