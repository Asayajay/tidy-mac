import SwiftUI
import TidyMacCore

/// The "review before it happens" step: shows exactly what would move and where,
/// and where it wouldn't touch anything (and why), before a single file moves.
/// Nothing here calls Organizer in `.live` mode until the user presses the button.
struct PreviewSheet: View {
    let folder: WatchedFolder
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var plan: OrganizationPlan? {
        appState.lastPlans[folder.id]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview: \(folder.displayName)")
                .font(.title3.bold())

            if let plan {
                if plan.moves.isEmpty {
                    Text("Nothing to organize here right now.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(plan.moves.count) file\(plan.moves.count == 1 ? "" : "s") would move:")
                        .font(.headline)
                    List(Array(plan.moves.enumerated()), id: \.offset) { _, move in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(move.source.lastPathComponent)
                                .fontWeight(.medium)
                            Text("→ \(move.destination.path)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Rule: \(move.ruleName)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(minHeight: 120, maxHeight: 260)
                }

                if !plan.skipped.isEmpty {
                    DisclosureGroup("\(plan.skipped.count) item\(plan.skipped.count == 1 ? "" : "s") left untouched") {
                        List(Array(plan.skipped.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Text(item.source.lastPathComponent)
                                Spacer()
                                Text(item.reason.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(minHeight: 60, maxHeight: 150)
                    }
                }
            } else {
                Text("Couldn't read this folder.")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Move These Files") {
                    appState.approveAndMove(folder: folder)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(plan?.moves.isEmpty ?? true)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            if plan == nil {
                appState.preview(folder: folder)
            }
        }
    }
}
