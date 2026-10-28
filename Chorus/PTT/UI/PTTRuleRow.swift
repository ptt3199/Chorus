import SwiftUI

/// One editable rule in the Links settings tab.
struct PTTRuleRow: View {
    let rule: PTTLinkRule
    let profileNames: [String]
    let onChange: (PTTLinkRule) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            kindPicker
            patternField
            profilePicker
            warning
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete this rule")
        }
    }

    private func edited(_ change: (inout PTTLinkRule) -> Void) -> PTTLinkRule {
        var copy = rule
        change(&copy)
        return copy
    }

    private var profileMissing: Bool {
        !rule.profile.isEmpty && !profileNames.contains(rule.profile)
    }

    private var kindPicker: some View {
        Picker("Kind", selection: Binding(
            get: { rule.kind },
            set: { kind in onChange(edited { $0.kind = kind }) }
        )) {
            Text("Domain").tag(PTTLinkRule.Kind.domain)
            Text("Wildcard").tag(PTTLinkRule.Kind.wildcard)
            Text("Regex").tag(PTTLinkRule.Kind.regex)
        }
        .labelsHidden()
        .fixedSize()
    }

    private var patternField: some View {
        TextField("Pattern", text: Binding(
            get: { rule.pattern },
            set: { text in onChange(edited { $0.pattern = text }) }
        ))
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
    }

    private var profilePicker: some View {
        Picker("Profile", selection: Binding(
            get: { rule.profile },
            set: { name in onChange(edited { $0.profile = name }) }
        )) {
            if rule.profile.isEmpty {
                Text("Choose…").tag("")
            }
            if profileMissing {
                Text("\(rule.profile) (not found)").tag(rule.profile)
            }
            ForEach(profileNames, id: \.self) { name in
                Text(name).tag(name)
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    @ViewBuilder
    private var warning: some View {
        if !rule.isValid {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .help(rule.kind == .regex
                    ? "This pattern is empty or not a valid regular expression, so it never matches."
                    : "The pattern is empty, so this rule never matches.")
        } else if profileMissing {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .help("Chrome has no profile named \(rule.profile).")
        }
    }
}
