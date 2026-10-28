import SwiftUI

/// Settings tab for link rules, the rule file, a link tester, the recent
/// links and the Chrome profiles.
struct PTTLinkSettingsTab: View {
    @State private var links = PTTLinkService.shared
    @State private var testURL = ""
    @State private var testProfile: String?

    var body: some View {
        Form {
            rulesSection
            fileSection
            testSection
            recentSection
            profilesSection
        }
        .formStyle(.grouped)
        .tabItem { Label("Links", systemImage: "arrow.up.right.square") }
        .onAppear { links.reloadRulesIfChanged() }
    }

    private var profileNames: [String] {
        links.profiles.map(\.name)
    }

    // MARK: - Rules

    private var rulesSection: some View {
        Section {
            ForEach(links.rules.rules) { rule in
                PTTRuleRow(
                    rule: rule,
                    profileNames: profileNames,
                    onChange: { update($0) },
                    onDelete: { delete(rule.id) }
                )
            }
            .onMove { source, destination in
                var updated = links.rules
                updated.rules.move(fromOffsets: source, toOffset: destination)
                links.saveRules(updated)
            }
            Button("Add Rule") { addRule() }
        } header: {
            Text("Rules")
        } footer: {
            Text("Rules are checked top to bottom and the first match wins. A rule wins over a service's own profile.")
        }
    }

    private func update(_ rule: PTTLinkRule) {
        var updated = links.rules
        guard let index = updated.rules.firstIndex(where: { $0.id == rule.id }) else { return }
        updated.rules[index] = rule
        links.saveRules(updated)
    }

    private func delete(_ id: UUID) {
        var updated = links.rules
        updated.rules.removeAll { $0.id == id }
        links.saveRules(updated)
    }

    private func addRule() {
        var updated = links.rules
        updated.rules.append(PTTLinkRule(kind: .domain, pattern: "", profile: profileNames.first ?? ""))
        links.saveRules(updated)
    }

    // MARK: - Rule file

    private var fileSection: some View {
        Section("Rule file") {
            Text(links.ruleFileURL.path)
                .font(.caption)
                .textSelection(.enabled)
            HStack {
                Button("Reveal in Finder") { links.revealRuleFile() }
                Button("Reload") {
                    links.reloadRules()
                    links.reloadProfiles()
                }
            }
            if let error = links.ruleFileError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Test a link

    private var testSection: some View {
        Section("Test a link") {
            TextField("URL", text: $testURL)
            Picker("As if clicked in a service using", selection: $testProfile) {
                Text("None").tag(String?.none)
                if let saved = testProfile, !profileNames.contains(saved) {
                    Text("\(saved) (not found)").tag(String?.some(saved))
                }
                ForEach(profileNames, id: \.self) { name in
                    Text(name).tag(String?.some(name))
                }
            }
            testResult
        }
    }

    @ViewBuilder
    private var testResult: some View {
        let text = testURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: text), !text.isEmpty {
            let result = links.resolve(url, serviceProfile: testProfile)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.url.absoluteString)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Text(branchText(result.branch))
                Text(targetText(result.target))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func branchText(_ branch: PTTLinkResolution.Branch) -> String {
        switch branch {
        case .rule(let rule): return "Rule: \(rule.kind.rawValue) \(rule.pattern)"
        case .serviceProfile: return "Service profile"
        case .chorusService, .fallback: return "No rule — Chorus decides"
        }
    }

    private func targetText(_ target: PTTLinkResolution.Target) -> String {
        switch target {
        case .unchanged: return "Opens the way Chorus does by default"
        case .chrome(let profile): return "Opens in Chrome: \(profile.name)"
        case .missingProfile(let name): return "Profile not found: \(name)"
        }
    }

    // MARK: - Recent links

    private var recentSection: some View {
        Section("Recent links") {
            if links.log.entries.isEmpty {
                Text("No links opened yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(links.log.entries) { entry in
                    PTTLogRow(entry: entry)
                }
            }
        }
    }

    // MARK: - Chrome profiles

    private var profilesSection: some View {
        Section("Chrome profiles") {
            if links.profiles.isEmpty {
                Text("Chrome's Local State was not found or could not be read.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(links.profiles, id: \.directory) { profile in
                    LabeledContent(profile.name) {
                        Text([profile.email, profile.directory].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}

private struct PTTLogRow: View {
    let entry: PTTLinkLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.url.absoluteString)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(details)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var details: String {
        var parts = [entry.date.formatted(date: .omitted, time: .standard)]
        if let service = entry.sourceService { parts.append(service) }
        if let rule = entry.rule { parts.append(rule) }
        parts.append(entry.profile ?? "Chorus")
        return parts.joined(separator: " · ")
    }
}
