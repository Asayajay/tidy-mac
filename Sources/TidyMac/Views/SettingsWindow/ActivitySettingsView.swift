import SwiftUI
import TidyMacCore

struct ActivitySettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if appState.batches.isEmpty {
                Text("No moves logged yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appState.batches) { batch in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(batch.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .fontWeight(.medium)
                            Text("\(batch.entries.count) file\(batch.entries.count == 1 ? "" : "s") moved")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(batch.entries.prefix(3)) { entry in
                                Text("\(URL(fileURLWithPath: entry.sourcePath).lastPathComponent) → \(entry.ruleName)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            if batch.entries.count > 3 {
                                Text("+ \(batch.entries.count - 3) more")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        if batch.undone {
                            Text("Undone")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Button("Undo") {
                                appState.undo(batchID: batch.id)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
    }
}
