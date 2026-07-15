import AppKit

/// Opening a Window scene via `openWindow(id:)` doesn't reliably hand it keyboard
/// focus right away, especially right after a click in the menu bar popover -- the
/// window appears, but keystrokes keep going wherever focus was before. Activating the
/// app and explicitly asking the specific window to become key, after the run loop has
/// had a moment to finish creating it, fixes that.
@MainActor
enum WindowFocus {
    static func claim(windowTitled title: String) {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.title == title })?.makeKeyAndOrderFront(nil)
        }
    }
}
