import SwiftUI
import TidyMacCore

/// Review-before-delete for empty folders, the same shape as the move preview: nothing
/// is removed until this is shown and approved. Presented as a .sheet from the Folders
/// tab in the Settings window (a normal window, not the menu bar's own popover -- that
/// combination is what corrupted the menu bar popover's layout elsewhere in this app).
struct EmptyFolderReviewView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<URL> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Empty folders")
                .font(.title3.bold())

            if appState.emptyFolderCandidates.isEmpty {
                Text("No empty folders found in this watched folder.")
                    .foregroundStyle(.secondary)
            } else {
                Text("These subfolders have nothing in them (ignoring Finder's .DS_Store file). Uncheck anything you want to keep.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                List(appState.emptyFolderCandidates, id: \.self) { url in
                    Toggle(isOn: Binding(
                        get: { selected.contains(url) },
                        set: { isOn in
                            if isOn { selected.insert(url) } else { selected.remove(url) }
                        }
                    )) {
                        Text(url.lastPathComponent)
                    }
                }
                .frame(minHeight: 120, maxHeight: 260)
            }

            HStack {
                Button("Cancel") {
                    close()
                }
                Spacer()
                Button(appState.emptyFolderCandidates.isEmpty ? "Close" : "Remove Selected") {
                    if !selected.isEmpty {
                        appState.removeEmptyFolders(Array(selected))
                    }
                    close()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!appState.emptyFolderCandidates.isEmpty && selected.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            selected = Set(appState.emptyFolderCandidates)
        }
    }

    private func close() {
        appState.folderForEmptyFolderReview = nil
        dismiss()
    }
}
