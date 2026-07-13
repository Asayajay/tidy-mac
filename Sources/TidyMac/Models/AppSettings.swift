import Foundation
import TidyMacCore

/// Whether an organize run actually moves files. Dry run is the default and stays the
/// default until the user explicitly changes it -- see the README's safety model.
enum OrganizeMode: String, Codable, CaseIterable, Identifiable {
    case dryRun
    case auto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dryRun: return "Dry Run (preview only)"
        case .auto: return "Auto-Organize (moves files)"
        }
    }
}

/// How often watched folders get checked.
enum TriggerMode: Codable, Equatable {
    case manualOnly
    case onFileSystemChange
    case scheduled(everyMinutes: Int)

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case manualOnly, onFileSystemChange, scheduled
        var id: String { rawValue }
        var title: String {
            switch self {
            case .manualOnly: return "Manual only"
            case .onFileSystemChange: return "When files change"
            case .scheduled: return "On a schedule"
            }
        }
    }

    var kind: Kind {
        switch self {
        case .manualOnly: return .manualOnly
        case .onFileSystemChange: return .onFileSystemChange
        case .scheduled: return .scheduled
        }
    }
}

struct AppSettings: Codable, Equatable {
    var mode: OrganizeMode = .dryRun
    var triggerMode: TriggerMode = .manualOnly
    var watchedFolders: [WatchedFolder] = []
    var rules: [FileRule] = DefaultRules.all

    static let `default` = AppSettings()
}
