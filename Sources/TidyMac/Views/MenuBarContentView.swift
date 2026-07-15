import SwiftUI
import AppKit
import TidyMacCore

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TidyMac")
                .font(.headline)

            Picker("", selection: $appState.settings.mode) {
                ForEach(OrganizeMode.allCases) { mode in
                    Text(mode.shortTitle).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if appState.settings.mode == .dryRun {
                Label("Nothing moves until you approve it", systemImage: "eye")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Files move automatically on trigger", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            if appState.settings.watchedFolders.isEmpty {
                Text("No folders yet. Add one in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.settings.watchedFolders) { folder in
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(folder.displayName)
                            .lineLimit(1)
                        Spacer()
                        Button("Organize Now") {
                            appState.preview(folder: folder)
                            appState.folderPendingReview = folder
                            openWindow(id: "preview")
                            WindowFocus.claim(windowTitled: "TidyMac Preview")
                        }
                        .controlSize(.small)
                    }
                }
            }

            Divider()

            if !appState.statusMessage.isEmpty {
                Text(appState.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Button {
                appState.undoLastBatch()
            } label: {
                Label("Undo Last Batch", systemImage: "arrow.uturn.backward")
            }
            .disabled(!appState.canUndoSomething)

            Divider()

            HStack {
                Button("Settings…") {
                    openWindow(id: "settings")
                    WindowFocus.claim(windowTitled: "TidyMac Settings")
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}
