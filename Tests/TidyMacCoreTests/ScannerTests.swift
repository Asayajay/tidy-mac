import XCTest
@testable import TidyMacCore

final class ScannerTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestSupport.makeTempDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func candidateURLs(_ entries: [ScannedEntry]) -> [URL] {
        entries.compactMap {
            if case .candidate(let c) = $0 { return c.url }
            return nil
        }
    }

    private func skipped(_ entries: [ScannedEntry], reason: SkipReason) -> [URL] {
        entries.compactMap {
            if case .skipped(let url, let r) = $0, r == reason { return url }
            return nil
        }
    }

    func testLooseFileAtRootIsACandidate() throws {
        let file = try TestSupport.writeFile(named: "notes.txt", in: tempDir)
        let entries = try Scanner().scan(root: tempDir)
        XCTAssertEqual(candidateURLs(entries), [file])
    }

    func testFileInsideSubfolderIsNeverTouchedByDefault() throws {
        let subfolder = tempDir.appendingPathComponent("My Organized Stuff", isDirectory: true)
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        try TestSupport.writeFile(named: "already-sorted.txt", in: subfolder)

        let entries = try Scanner().scan(root: tempDir)
        XCTAssertTrue(candidateURLs(entries).isEmpty)
        XCTAssertEqual(skipped(entries, reason: .isSubfolder), [subfolder])
    }

    func testNoExtensionFileIsStillAValidCandidate() throws {
        let file = try TestSupport.writeFile(named: "README", in: tempDir)
        let entries = try Scanner().scan(root: tempDir)
        XCTAssertEqual(candidateURLs(entries), [file])
        if case .candidate(let candidate) = entries.first(where: { if case .candidate = $0 { return true }; return false })! {
            XCTAssertEqual(candidate.pathExtension, "")
        }
    }

    func testSymlinkIsSkippedNotTreatedAsCandidate() throws {
        let target = try TestSupport.writeFile(named: "real-file.txt", in: tempDir)
        let linkURL = tempDir.appendingPathComponent("link-to-file.txt")
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: target)

        let entries = try Scanner().scan(root: tempDir)
        XCTAssertEqual(candidateURLs(entries), [target])
        XCTAssertEqual(skipped(entries, reason: .isSymlink), [linkURL])
    }

    func testSymlinkToDirectoryIsSkippedAsSymlinkNotRecursedInto() throws {
        let realDir = try TestSupport.makeTempDirectory(function: "realDirTarget")
        try TestSupport.writeFile(named: "inside.txt", in: realDir)
        defer { try? FileManager.default.removeItem(at: realDir) }

        let linkURL = tempDir.appendingPathComponent("link-to-dir")
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: realDir)

        let entries = try Scanner().scan(root: tempDir)
        XCTAssertTrue(candidateURLs(entries).isEmpty)
        XCTAssertEqual(skipped(entries, reason: .isSymlink), [linkURL])
    }

    func testUnreadableFileIsSkippedWithPermissionDenied() throws {
        let file = try TestSupport.writeFile(named: "locked.txt", in: tempDir)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path) }

        // Root can still read anything, so this check only meaningfully verifies behavior
        // when not running as root. Skip in that unusual case rather than produce a false failure.
        try XCTSkipIf(getuid() == 0, "Running as root bypasses POSIX permission bits")

        let entries = try Scanner().scan(root: tempDir)
        XCTAssertTrue(candidateURLs(entries).isEmpty)
        XCTAssertEqual(skipped(entries, reason: .permissionDenied), [file])
    }

    func testHiddenFilesAreSkippedEntirely() throws {
        try TestSupport.writeFile(named: ".DS_Store", in: tempDir)
        let entries = try Scanner().scan(root: tempDir)
        XCTAssertTrue(entries.isEmpty)
    }

    func testGenericSubfolderIsLeftAloneByDefault() throws {
        let generic = tempDir.appendingPathComponent("New Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: generic, withIntermediateDirectories: true)
        try TestSupport.writeFile(named: "loose.txt", in: generic)

        let entries = try Scanner(settings: ScanSettings(includeGenericSubfolders: false)).scan(root: tempDir)
        XCTAssertTrue(candidateURLs(entries).isEmpty)
        XCTAssertEqual(skipped(entries, reason: .isSubfolder), [generic])
    }

    func testGenericSubfolderIsScannedOnlyWhenOptedIn() throws {
        let generic = tempDir.appendingPathComponent("New Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: generic, withIntermediateDirectories: true)
        let inner = try TestSupport.writeFile(named: "loose.txt", in: generic)

        let entries = try Scanner(settings: ScanSettings(includeGenericSubfolders: true)).scan(root: tempDir)
        XCTAssertEqual(candidateURLs(entries), [inner])
    }

    func testNamedSubfolderIsNotScannedEvenWhenGenericOptInIsOn() throws {
        // Opting into "clean up generic-looking subfolders" must not turn into
        // "recurse into everything." A folder the user actually named is still off-limits.
        let named = tempDir.appendingPathComponent("Tax Documents 2024", isDirectory: true)
        try FileManager.default.createDirectory(at: named, withIntermediateDirectories: true)
        try TestSupport.writeFile(named: "w2.pdf", in: named)

        let entries = try Scanner(settings: ScanSettings(includeGenericSubfolders: true)).scan(root: tempDir)
        XCTAssertTrue(candidateURLs(entries).isEmpty)
        XCTAssertEqual(skipped(entries, reason: .isSubfolder), [named])
    }

    func testGenericSubfolderRecursionIsOnlyOneLevelDeep() throws {
        let generic = tempDir.appendingPathComponent("New Folder", isDirectory: true)
        let nestedDir = generic.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        try TestSupport.writeFile(named: "deep.txt", in: nestedDir)

        let entries = try Scanner(settings: ScanSettings(includeGenericSubfolders: true)).scan(root: tempDir)
        XCTAssertTrue(candidateURLs(entries).isEmpty)
        XCTAssertEqual(skipped(entries, reason: .isSubfolder), [nestedDir])
    }
}
