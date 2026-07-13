import Foundation

/// Why a given item was left alone instead of moved. Every skip is reported in the plan
/// so dry-run output can explain itself -- nothing is silently ignored.
public enum SkipReason: Equatable, CustomStringConvertible {
    case isSubfolder
    case isSymlink
    case noRuleMatched
    case fileInUse
    case permissionDenied
    case destinationConflictUnresolvable

    public var description: String {
        switch self {
        case .isSubfolder:
            return "Inside a subfolder (assumed already organized)"
        case .isSymlink:
            return "Symlink (never moved automatically)"
        case .noRuleMatched:
            return "No rule matched this file"
        case .fileInUse:
            return "File appears to be open/in use"
        case .permissionDenied:
            return "No read permission"
        case .destinationConflictUnresolvable:
            return "Could not find a non-colliding destination name"
        }
    }
}
