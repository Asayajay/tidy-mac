import XCTest
@testable import TidyMacCore

/// Dry run is the whole safety story of this app, so it gets tested at a different level
/// than "does it report the right thing": every test here proves nothing was written to
/// the real filesystem, by snapshotting the directory tree before and after and asserting
/// it is byte-for-byte identical.
final class DryRunSafetyTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestSupport.makeTempDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testDryRunMakesZeroFilesystemWrites() throws {
        try TestSupport.writeFile(named: "Screenshot 2024-01-01 at 3.14.15 PM.png", in: tempDir)
        try TestSupport.writeFile(named: "taxes.pdf", in: tempDir)
        try TestSupport.writeFile(named: "installer.dmg", in: tempDir)
        try TestSupport.writeFile(named: "README", in: tempDir)
        let organizedAlready = tempDir.appendingPathComponent("Already Organized", isDirectory: true)
        try FileManager.default.createDirectory(at: organizedAlready, withIntermediateDirectories: true)
        try TestSupport.writeFile(named: "keep-me.txt", in: organizedAlready)

        let before = try TestSupport.fingerprint(of: tempDir)
        let organizer = Organizer(rules: DefaultRules.all)
        let result = try organizer.run(for: tempDir, mode: .dryRun)
        let after = try TestSupport.fingerprint(of: tempDir)

        XCTAssertFalse(result.plan.moves.isEmpty, "expected the plan to find something to do, or this test proves nothing")
        XCTAssertNil(result.batch, "dry run must never produce a batch")
        XCTAssertEqual(before, after, "dry run must not change a single byte on disk")
    }

    func testDryRunDoesNotCreateDestinationDirectories() throws {
        try TestSupport.writeFile(named: "taxes.pdf", in: tempDir)
        let organizer = Organizer(rules: DefaultRules.all)
        _ = try organizer.run(for: tempDir, mode: .dryRun)

        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("Documents").path))
    }

    func testDryRunPlanMatchesWhatLiveRunWouldActuallyDo() throws {
        try TestSupport.writeFile(named: "taxes.pdf", in: tempDir)
        try TestSupport.writeFile(named: "Screenshot 2024-01-01 at 3.14.15 PM.png", in: tempDir)

        let organizer = Organizer(rules: DefaultRules.all)
        let dryRunResult = try organizer.run(for: tempDir, mode: .dryRun)

        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let liveResult = try organizer.run(for: tempDir, mode: .live(operations: LiveFileOperations(), logStore: logStore))

        let dryDestinations = Set(dryRunResult.plan.moves.map(\.destination.path))
        let liveDestinations = Set(liveResult.plan.moves.map(\.destination.path))
        XCTAssertEqual(dryDestinations, liveDestinations)
    }

    func testCallingDryRunRepeatedlyIsIdempotentAndSideEffectFree() throws {
        try TestSupport.writeFile(named: "taxes.pdf", in: tempDir)
        let organizer = Organizer(rules: DefaultRules.all)

        let before = try TestSupport.fingerprint(of: tempDir)
        for _ in 0..<5 {
            _ = try organizer.run(for: tempDir, mode: .dryRun)
        }
        let after = try TestSupport.fingerprint(of: tempDir)
        XCTAssertEqual(before, after)
    }
}
