import XCTest
@testable import TidyMacCore

final class EmptyFolderScannerTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestSupport.makeTempDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testFindsATrulyEmptyFolder() throws {
        let empty = tempDir.appendingPathComponent("Empty", isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)

        let found = try EmptyFolderScanner().findEmptyFolders(in: tempDir)
        XCTAssertEqual(found, [empty])
    }

    func testFolderWithOnlyDSStoreCountsAsEmpty() throws {
        let folder = tempDir.appendingPathComponent("LooksEmpty", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try TestSupport.writeFile(named: ".DS_Store", in: folder)

        let found = try EmptyFolderScanner().findEmptyFolders(in: tempDir)
        XCTAssertEqual(found, [folder])
    }

    func testFolderWithARealFileIsNotEmpty() throws {
        let folder = tempDir.appendingPathComponent("HasStuff", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try TestSupport.writeFile(named: "notes.txt", in: folder)

        let found = try EmptyFolderScanner().findEmptyFolders(in: tempDir)
        XCTAssertTrue(found.isEmpty)
    }

    func testFolderContainingOnlyAnEmptySubfolderIsNotFlattenedOrTouched() throws {
        // The nested empty folder isn't scanned at all (only one level deep), so the
        // parent isn't empty from this scan's point of view -- it has a subfolder in it.
        let parent = tempDir.appendingPathComponent("Parent", isDirectory: true)
        let child = parent.appendingPathComponent("Child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)

        let found = try EmptyFolderScanner().findEmptyFolders(in: tempDir)
        XCTAssertTrue(found.isEmpty)
    }

    func testLooseFilesAtRootAreIgnoredNotTreatedAsFolders() throws {
        try TestSupport.writeFile(named: "notes.txt", in: tempDir)
        let found = try EmptyFolderScanner().findEmptyFolders(in: tempDir)
        XCTAssertTrue(found.isEmpty)
    }

    func testSymlinkToAnEmptyDirectoryIsNeverOfferedForRemoval() throws {
        let realEmptyDir = try TestSupport.makeTempDirectory(function: "realEmptyDir")
        defer { try? FileManager.default.removeItem(at: realEmptyDir) }
        let link = tempDir.appendingPathComponent("link", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: realEmptyDir)

        let found = try EmptyFolderScanner().findEmptyFolders(in: tempDir)
        XCTAssertTrue(found.isEmpty)
    }
}

final class EmptyFolderRemoverTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestSupport.makeTempDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testRemovesOnlyTheFoldersItsGivenAndLogsTheBatch() throws {
        let empty1 = tempDir.appendingPathComponent("Empty1", isDirectory: true)
        let empty2 = tempDir.appendingPathComponent("Empty2", isDirectory: true)
        try FileManager.default.createDirectory(at: empty1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: empty2, withIntermediateDirectories: true)

        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let remover = EmptyFolderRemover(logStore: logStore)
        let result = try remover.remove([empty1, empty2], operations: LiveFileOperations())

        XCTAssertEqual(result.removedCount, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: empty1.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: empty2.path))
        XCTAssertEqual(logStore.loadBatches().first?.removedEmptyFolders.sorted(), [empty1.path, empty2.path].sorted())
    }

    func testDoesNotRemoveAFolderThatGainedAFileSincePreview() throws {
        // Re-verified right before removal, not trusted from an earlier scan.
        let folder = tempDir.appendingPathComponent("WasEmpty", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try TestSupport.writeFile(named: "surprise.txt", contents: "new", in: folder)

        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let remover = EmptyFolderRemover(logStore: logStore)
        let result = try remover.remove([folder], operations: LiveFileOperations())

        XCTAssertEqual(result.removedCount, 0)
        XCTAssertEqual(result.skipped, [folder])
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("surprise.txt").path))
    }

    func testRemovingADSStoreOnlyFolderAlsoRemovesTheDSStoreFile() throws {
        let folder = tempDir.appendingPathComponent("LooksEmpty", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try TestSupport.writeFile(named: ".DS_Store", in: folder)

        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let remover = EmptyFolderRemover(logStore: logStore)
        let result = try remover.remove([folder], operations: LiveFileOperations())

        XCTAssertEqual(result.removedCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    func testNoBatchLoggedWhenNothingWasActuallyRemoved() throws {
        let folder = tempDir.appendingPathComponent("NotEmpty", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try TestSupport.writeFile(named: "a.txt", in: folder)

        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let remover = EmptyFolderRemover(logStore: logStore)
        let result = try remover.remove([folder], operations: LiveFileOperations())

        XCTAssertNil(result.batch)
        XCTAssertTrue(logStore.loadBatches().isEmpty)
    }

    func testUndoRecreatesTheRemovedEmptyFolder() throws {
        let folder = tempDir.appendingPathComponent("Empty", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let remover = EmptyFolderRemover(logStore: logStore)
        _ = try remover.remove([folder], operations: LiveFileOperations())
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))

        let undoer = MoveUndoer(logStore: logStore, operations: LiveFileOperations())
        let outcome = try undoer.undoLastBatch()

        XCTAssertEqual(outcome.restoredFolderCount, 1)
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testUndoSkipsRecreatingIfSomethingNowOccupiesThatPath() throws {
        let folder = tempDir.appendingPathComponent("Empty", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let logStore = MoveLogStore(fileURL: tempDir.appendingPathComponent("log.json"))
        let remover = EmptyFolderRemover(logStore: logStore)
        _ = try remover.remove([folder], operations: LiveFileOperations())

        // Someone put a real file at that exact path in the meantime.
        try TestSupport.writeFile(named: "Empty", contents: "surprise", in: tempDir)

        let undoer = MoveUndoer(logStore: logStore, operations: LiveFileOperations())
        let outcome = try undoer.undoLastBatch()

        XCTAssertEqual(outcome.restoredFolderCount, 0)
        XCTAssertEqual(try String(contentsOf: folder, encoding: .utf8), "surprise")
    }
}
