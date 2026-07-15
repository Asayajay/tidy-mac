import SwiftUI
import AppKit

@main
struct TidyMacApp: App {
    @StateObject private var appState = AppState()

    init() {
        // A pure MenuBarExtra app defaults to the .accessory activation policy (no Dock
        // icon), but that policy is unreliable at actually making the Settings/Preview
        // windows become key (focused for typing) when opened from the menu bar popover --
        // clicks landed in the field visually, but keystrokes kept going to whatever
        // window had focus before, confirmed on a real machine. .regular trades a Dock
        // icon for windows that reliably take keyboard focus.
        NSApplication.shared.setActivationPolicy(.regular)
    }

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
        // .contentSize locks the window to exactly its content's size, which also
        // disables resizing and full screen. .contentMinSize uses that size as a floor
        // instead, so the window can still be dragged larger or made full screen.
        .windowResizability(.contentMinSize)

        Window("TidyMac Preview", id: "preview") {
            PreviewSheet()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
    }
}
