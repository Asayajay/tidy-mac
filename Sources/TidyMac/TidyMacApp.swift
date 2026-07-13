import SwiftUI

@main
struct TidyMacApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("TidyMac", systemImage: "tray.and.arrow.down") {
            MenuBarContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Window("TidyMac Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}
