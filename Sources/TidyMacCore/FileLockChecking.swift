import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Best-effort check for "is this file currently open/in use." macOS has no mandatory
/// file locking, so this can only catch processes that cooperate via advisory `flock`
/// (which is most well-behaved apps, but not a guarantee for every process). It's a
/// safety net, not a promise -- documented as such in the README.
public protocol FileLockChecking {
    func isLocked(_ url: URL) -> Bool
}

public struct PosixFileLockChecker: FileLockChecking {
    public init() {}

    public func isLocked(_ url: URL) -> Bool {
        let fd = open(url.path, O_RDONLY)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            return true
        }
        flock(fd, LOCK_UN)
        return false
    }
}
