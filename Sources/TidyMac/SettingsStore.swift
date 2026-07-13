import Foundation

/// Persists `AppSettings` as JSON in Application Support. Kept deliberately dumb --
/// load once at launch, save on every change -- since settings are small and changed
/// rarely compared to the move log.
enum SettingsStore {
    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("TidyMac", isDirectory: true).appendingPathComponent("settings.json")
    }

    static func load() -> AppSettings {
        guard let data = try? Data(contentsOf: fileURL) else { return .default }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? .default
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    static var moveLogURL: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("move-log.json")
    }
}
