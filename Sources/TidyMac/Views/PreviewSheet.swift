import SwiftUI
import TidyMacCore

/// The "review before it happens" step: shows exactly what would move and where,
/// and where it wouldn't touch anything (and why), before a single file moves.
/// Nothing here calls Organizer in `.live` mode until the user presses the button.
///
/// This is its own Window scene, opened via `openWindow(id: "preview")`, reading
/// which folder to show from `appState.folderPendingReview`. It used to be a `.sheet`
/// attached directly to the menu bar dropdown's own view, but presenting a sheet from
/// inside a MenuBarExtra(.window) popover corrupted that popover's own layout (its
/// content came out clipped on both edges), reproduced on a real machine. A plain
/// Window scene doesn't have that problem.
struct PreviewSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var folder: WatchedFolder? {
        appState.folderPendingReview
    }

    private var plan: OrganizationPlan? {
        folder.flatMap { appState.lastPlans[$0.id] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let folder {
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
                        close()
                    }
                    Spacer()
                    Button("Move These Files") {
                        appState.approveAndMove(folder: folder)
                        close()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(plan?.moves.isEmpty ?? true)
                }
            } else {
                Text("No folder selected.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func close() {
        appState.folderPendingReview = nil
        dismiss()
    }
}
