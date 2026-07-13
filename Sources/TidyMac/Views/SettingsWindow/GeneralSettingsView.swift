import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var scheduleMinutes: Int = 30

    private var triggerKindBinding: Binding<TriggerMode.Kind> {
        Binding(
            get: { appState.settings.triggerMode.kind },
            set: { newKind in
                switch newKind {
                case .manualOnly:
                    appState.settings.triggerMode = .manualOnly
                case .onFileSystemChange:
                    appState.settings.triggerMode = .onFileSystemChange
                case .scheduled:
                    appState.settings.triggerMode = .scheduled(everyMinutes: scheduleMinutes)
                }
            }
        )
    }

    var body: some View {
        Form {
            Section("Safety") {
                Picker("Mode", selection: $appState.settings.mode) {
                    ForEach(OrganizeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(appState.settings.mode == .dryRun
                     ? "Every run only previews what would move. Nothing is touched until you press \"Move These Files.\""
                     : "Triggers move files immediately, without a per-run review. Every move is still logged and can be undone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("When to check watched folders") {
                Picker("Trigger", selection: triggerKindBinding) {
                    ForEach(TriggerMode.Kind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }

                if triggerKindBinding.wrappedValue == .scheduled {
                    Stepper(value: $scheduleMinutes, in: 1...240) {
                        Text("Every \(scheduleMinutes) minute\(scheduleMinutes == 1 ? "" : "s")")
                    }
                    .onChange(of: scheduleMinutes) { newValue in
                        appState.settings.triggerMode = .scheduled(everyMinutes: newValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if case .scheduled(let minutes) = appState.settings.triggerMode {
                scheduleMinutes = minutes
            }
        }
    }
}
