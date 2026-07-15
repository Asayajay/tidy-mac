import SwiftUI

@main
struct TidyMacApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("TidyMac", systemImage: "wand.and.sparkles") {
            MenuBarContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Window("TidyMac Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)

        Window("TidyMac Preview", id: "preview") {
            PreviewSheet()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}
