import SwiftUI
import TidyMacCore

struct RulesSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedRuleID: FileRule.ID?

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedRuleID) {
                    ForEach(appState.settings.rules) { rule in
                        HStack {
                            Toggle("", isOn: enabledBinding(for: rule))
                                .labelsHidden()
                            VStack(alignment: .leading) {
                                Text(rule.name)
                                Text(rule.destinationSubpath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(rule.id)
                    }
                    .onMove { indices, newOffset in
                        appState.settings.rules.move(fromOffsets: indices, toOffset: newOffset)
                    }
                    .onDelete { indices in
                        appState.settings.rules.remove(atOffsets: indices)
                    }
                }
                HStack {
                    Button("Add Rule", action: addRule)
                    Button("Reset to Defaults") {
                        appState.settings.rules = DefaultRules.all
                    }
                }
                .padding(8)
            }
            .frame(minWidth: 220)

            if let selectedRuleID, let index = appState.settings.rules.firstIndex(where: { $0.id == selectedRuleID }) {
                RuleEditorView(rule: $appState.settings.rules[index])
                    .padding()
            } else {
                Text("Select a rule to edit, or add a new one.\n\nRules are checked in order from top to bottom -- the first one whose conditions match wins, so put more specific rules (like Screenshots) above more general ones (like Images).")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
        }
    }

    private func enabledBinding(for rule: FileRule) -> Binding<Bool> {
        Binding(
            get: { rule.isEnabled },
            set: { newValue in
                if let index = appState.settings.rules.firstIndex(where: { $0.id == rule.id }) {
                    appState.settings.rules[index].isEnabled = newValue
                }
            }
        )
    }

    private func addRule() {
        let newRule = FileRule(
            name: "New Rule",
            conditions: [MatchCondition(kind: .fileExtension, value: "")],
            destinationSubpath: "New Folder"
        )
        appState.settings.rules.append(newRule)
        selectedRuleID = newRule.id
    }
}

private struct RuleEditorView: View {
    @Binding var rule: FileRule

    var body: some View {
        Form {
            Section("Rule") {
                TextField("Name", text: $rule.name)
                TextField("Destination (relative to watched folder)", text: $rule.destinationSubpath)
                Picker("Match if", selection: $rule.conditionLogic) {
                    Text("Any condition matches").tag(FileRule.ConditionLogic.any)
                    Text("All conditions match").tag(FileRule.ConditionLogic.all)
                }
            }

            Section("Conditions") {
                ForEach($rule.conditions) { $condition in
                    HStack {
                        Picker("", selection: $condition.kind) {
                            Text("Extension is").tag(MatchCondition.Kind.fileExtension)
                            Text("Name contains").tag(MatchCondition.Kind.filenameContains)
                            Text("Name starts with").tag(MatchCondition.Kind.filenamePrefix)
                            Text("Name matches regex").tag(MatchCondition.Kind.filenameRegex)
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        TextField("Value", text: $condition.value)
                        Button(role: .destructive) {
                            rule.conditions.removeAll { $0.id == condition.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button("Add Condition") {
                    rule.conditions.append(MatchCondition(kind: .fileExtension, value: ""))
                }
            }
        }
        .formStyle(.grouped)
    }
}
