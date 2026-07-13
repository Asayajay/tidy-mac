import Foundation
import TidyMacCore

/// One folder the user has chosen to watch, plus per-folder scan settings. Kept
/// independent so "clean up generic subfolders" can be opted into per folder instead of
/// globally -- someone might want that for Downloads but never for Desktop.
struct WatchedFolder: Codable, Equatable, Identifiable {
    var id: UUID
    var path: String
    var isEnabled: Bool
    var scanSettings: ScanSettings

    init(id: UUID = UUID(), path: String, isEnabled: Bool = true, scanSettings: ScanSettings = ScanSettings()) {
        self.id = id
        self.path = path
        self.isEnabled = isEnabled
        self.scanSettings = scanSettings
    }

    var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    var displayName: String {
        url.lastPathComponent
    }
}
