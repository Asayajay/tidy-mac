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

/// Deliberately not a `Form`. A `Form`/`Section` on macOS tries to lay its children out
/// as aligned label/value columns, and that heuristic badly misjudged the Conditions
/// row here (Picker + TextField + delete button), squeezing the text field down to a
/// sliver a few points wide -- confirmed on a real machine, its placeholder text
/// rendered one letter per line. Plain VStack/HStack with explicit widths sidesteps
/// that heuristic entirely.
private struct RuleEditorView: View {
    @Binding var rule: FileRule

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Rule") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledRow(label: "Name") {
                            TextField("Rule name", text: $rule.name)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledRow(label: "Destination") {
                            TextField("e.g. Documents/PDFs", text: $rule.destinationSubpath)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledRow(label: "Match if") {
                            Picker("", selection: $rule.conditionLogic) {
                                Text("Any condition matches").tag(FileRule.ConditionLogic.any)
                                Text("All conditions match").tag(FileRule.ConditionLogic.all)
                            }
                            .labelsHidden()
                        }
                    }
                    .padding(10)
                }

                GroupBox("Conditions") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach($rule.conditions) { $condition in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Picker("", selection: $condition.kind) {
                                        Text("Extension is").tag(MatchCondition.Kind.fileExtension)
                                        Text("Name contains").tag(MatchCondition.Kind.filenameContains)
                                        Text("Name starts with").tag(MatchCondition.Kind.filenamePrefix)
                                        Text("Name matches regex").tag(MatchCondition.Kind.filenameRegex)
                                    }
                                    .labelsHidden()
                                    .frame(width: 170)

                                    TextField(condition.kind.placeholder, text: $condition.value)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(minWidth: 100, maxWidth: .infinity)

                                    Button(role: .destructive) {
                                        rule.conditions.removeAll { $0.id == condition.id }
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                Text(condition.kind.helpText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 178)
                            }
                        }
                        Button("Add Condition") {
                            rule.conditions.append(MatchCondition(kind: .fileExtension, value: ""))
                        }
                    }
                    .padding(10)
                }
            }
            .padding()
        }
    }
}

/// Plain-language example text per condition kind, shown right under the row so
/// picking "Name matches regex" doesn't leave someone guessing what to type there.
private extension MatchCondition.Kind {
    var placeholder: String {
        switch self {
        case .fileExtension: return "pdf"
        case .filenameContains: return "invoice"
        case .filenamePrefix: return "IMG_"
        case .filenameRegex: return "^Screen ?Shot .*"
        }
    }

    var helpText: String {
        switch self {
        case .fileExtension: return "Matches the file's extension, without the dot (e.g. \"pdf\", not \".pdf\")."
        case .filenameContains: return "Matches if this text appears anywhere in the filename."
        case .filenamePrefix: return "Matches if the filename starts with this text."
        case .filenameRegex: return "Advanced: matches using a regular expression against the filename."
        }
    }
}

private struct LabeledRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(.secondary)
            content
        }
    }
}
