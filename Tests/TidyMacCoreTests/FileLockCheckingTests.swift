import XCTest
@testable import TidyMacCore
#if canImport(Darwin)
import Darwin
#endif

final class FileLockCheckingTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = try TestSupport.makeTempDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testUnlockedFileIsNotReportedAsLocked() throws {
        let file = try TestSupport.writeFile(named: "free.txt", in: tempDir)
        XCTAssertFalse(PosixFileLockChecker().isLocked(file))
    }

    func testFileHeldWithExclusiveFlockIsReportedAsLocked() throws {
        // flock is per open-file-description, so a second file descriptor -- even from
        // this same process -- correctly conflicts with an existing exclusive lock.
        // This lets us test the "in use" detection deterministically, no second process needed.
        let file = try TestSupport.writeFile(named: "busy.txt", in: tempDir)
        let fd = open(file.path, O_RDONLY)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { close(fd) }
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), 0)

        XCTAssertTrue(PosixFileLockChecker().isLocked(file))
    }

    func testFileIsNoLongerLockedAfterReleased() throws {
        let file = try TestSupport.writeFile(named: "busy2.txt", in: tempDir)
        let fd = open(file.path, O_RDONLY)
        XCTAssertGreaterThanOrEqual(fd, 0)
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), 0)
        flock(fd, LOCK_UN)
        close(fd)

        XCTAssertFalse(PosixFileLockChecker().isLocked(file))
    }

    func testCheckingLockDoesNotItselfHoldTheLock() throws {
        // isLocked must release its own probing lock; otherwise the second call
        // in a plan-then-execute flow would deadlock/false-positive on its own check.
        let file = try TestSupport.writeFile(named: "reentrant.txt", in: tempDir)
        let checker = PosixFileLockChecker()
        XCTAssertFalse(checker.isLocked(file))
        XCTAssertFalse(checker.isLocked(file))
    }
}
