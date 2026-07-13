import SwiftUI
import AppKit

struct FoldersSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List {
                ForEach(appState.settings.watchedFolders) { folder in
                    FolderRow(folder: folder)
                }
            }
            .frame(minHeight: 220)

            HStack {
                Button("Add Folder…") {
                    addFolder()
                }
                Spacer()
            }
        }
        .padding()
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Watch This Folder"
        if panel.runModal() == .OK, let url = panel.url {
            appState.addFolder(url: url)
        }
    }
}

private struct FolderRow: View {
    let folder: WatchedFolder
    @EnvironmentObject private var appState: AppState

    private var folderBinding: Binding<WatchedFolder> {
        Binding(
            get: { appState.settings.watchedFolders.first(where: { $0.id == folder.id }) ?? folder },
            set: { updated in
                guard let index = appState.settings.watchedFolders.firstIndex(where: { $0.id == folder.id }) else { return }
                appState.settings.watchedFolders[index] = updated
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle("", isOn: folderBinding.isEnabled)
                    .labelsHidden()
                Text(folder.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(role: .destructive) {
                    appState.removeFolder(id: folder.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            Toggle("Also clean up generic-looking subfolders (e.g. \"New Folder\")", isOn: folderBinding.scanSettings.includeGenericSubfolders)
                .font(.caption)
                .padding(.leading, 24)
        }
        .padding(.vertical, 4)
    }
}
