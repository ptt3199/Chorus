import AppKit
import Foundation
import Observation
import os

/// Opens links in the right Chrome profile. Holds the rule file, the Chrome
/// profile list and the in-memory link log; Settings and Edit Service read
/// and change them through here.
@MainActor
@Observable
final class PTTLinkService {
    static let shared = PTTLinkService()

    nonisolated static let logger = Logger(subsystem: "com.ptt3199.Chorus", category: "PTTLinks")

    /// The hand-editable rule file.
    let ruleFileURL: URL

    private(set) var rules: PTTRuleSet = .defaults
    /// Why the rule file could not be read, shown in Settings. The last good
    /// rules stay in use meanwhile.
    private(set) var ruleFileError: String?
    private(set) var profiles: [PTTChromeProfile] = []
    private(set) var log = PTTLinkLog()

    /// The label of a service, for the log. Set by `AppState`.
    @ObservationIgnored var serviceName: ((UUID) -> String?)?

    @ObservationIgnored private var ruleFileDate: Date?
    @ObservationIgnored private let serviceProfiles = PTTServiceProfiles()

    init(ruleFileURL: URL = PTTAppIdentity.supportFolder.appending(path: "link-rules.json")) {
        self.ruleFileURL = ruleFileURL
        reloadRules()
        reloadProfiles()
    }

    // MARK: - Rules

    /// Reads the rule file, writing the default rules first when it does not
    /// exist yet.
    func reloadRules() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: ruleFileURL.path) {
            write(.defaults)
        }
        do {
            let data = try Data(contentsOf: ruleFileURL)
            rules = try PTTRuleSet.decode(data)
            ruleFileError = nil
        } catch {
            ruleFileError = error.localizedDescription
            Self.logger.error("Could not read link rules: \(error.localizedDescription, privacy: .public)")
        }
        ruleFileDate = modificationDate()
    }

    /// Picks up edits made to the file by hand since the last read.
    func reloadRulesIfChanged() {
        if modificationDate() != ruleFileDate { reloadRules() }
    }

    func saveRules(_ newRules: PTTRuleSet) {
        rules = newRules
        write(newRules)
        ruleFileError = nil
        ruleFileDate = modificationDate()
    }

    func revealRuleFile() {
        reloadRulesIfChanged()
        NSWorkspace.shared.activateFileViewerSelecting([ruleFileURL])
    }

    private func write(_ set: PTTRuleSet) {
        do {
            try FileManager.default.createDirectory(
                at: ruleFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try set.encoded().write(to: ruleFileURL, options: .atomic)
        } catch {
            ruleFileError = error.localizedDescription
            Self.logger.error("Could not write link rules: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func modificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: ruleFileURL.path))?[.modificationDate] as? Date
    }

    // MARK: - Profiles

    func reloadProfiles() {
        profiles = PTTChromeProfiles.load()
    }

    func serviceProfile(for serviceID: UUID) -> String? {
        serviceProfiles.profile(for: serviceID)
    }

    func setServiceProfile(_ name: String?, for serviceID: UUID) {
        serviceProfiles.setProfile(name, for: serviceID)
    }

    // MARK: - Routing

    /// What would happen to `url` clicked in a service whose profile is
    /// `serviceProfile`. Used by the Settings tester.
    func resolve(_ url: URL, serviceProfile: String?, ownedByChorus: Bool = false) -> PTTLinkResolution {
        reloadRulesIfChanged()
        return PTTLinkResolver.resolve(
            url,
            isOwnedByChorusService: { _ in ownedByChorus },
            serviceProfile: serviceProfile,
            rules: rules,
            profiles: profiles
        )
    }

    /// Opens `url` in a Chrome profile when a rule or the source service says
    /// so. Returns false when Chorus should handle the link as it always did.
    func route(_ url: URL, from sourceServiceID: UUID?, ownedByChorus: Bool = false, onlyChrome: Bool = false) -> Bool {
        reloadProfiles()
        let resolution = resolve(
            url,
            serviceProfile: sourceServiceID.flatMap(serviceProfile(for:)),
            ownedByChorus: ownedByChorus
        )
        switch resolution.target {
        case .unchanged:
            if !onlyChrome { record(resolution, from: sourceServiceID) }
            return false
        case .chrome(let profile):
            record(resolution, from: sourceServiceID)
            open(resolution.url, in: profile)
            return true
        case .missingProfile(let name):
            if onlyChrome { return false }
            record(resolution, from: sourceServiceID)
            Self.logger.error("No Chrome profile named \(name, privacy: .public); opening in the default browser")
            NSWorkspace.shared.open(resolution.url)
            return true
        }
    }

    /// Opens `url` in the profile the user picked from a menu, unwrapping a
    /// redirect and adding `authuser` the same way routing does.
    func open(_ url: URL, inProfileNamed name: String, from sourceServiceID: UUID?) {
        reloadProfiles()
        let unwrapped = PTTURLRewriting.unwrapRedirect(url)
        guard let profile = PTTChromeProfiles.find(name, in: profiles) else {
            Self.logger.error("No Chrome profile named \(name, privacy: .public); opening in the default browser")
            NSWorkspace.shared.open(unwrapped)
            return
        }
        let target = PTTURLRewriting.addingAuthUser(to: unwrapped, email: profile.email)
        log.record(PTTLinkLogEntry(
            date: Date(), url: target, sourceService: sourceServiceID.flatMap { serviceName?($0) },
            rule: "menu", profile: profile.name))
        open(target, in: profile)
    }

    /// Adds a domain rule for the link's host, then opens the link with it.
    func alwaysOpen(_ url: URL, inProfileNamed name: String, from sourceServiceID: UUID?) {
        guard let host = PTTURLRewriting.unwrapRedirect(url).host else { return }
        reloadRulesIfChanged()
        var updated = rules
        updated.prependDomainRule(host: host, profile: name)
        saveRules(updated)
        open(url, inProfileNamed: name, from: sourceServiceID)
    }

    private func record(_ resolution: PTTLinkResolution, from sourceServiceID: UUID?) {
        let name = sourceServiceID.flatMap { serviceName?($0) }
        log.record(PTTLinkLog.entry(for: resolution, sourceService: name))
    }

    /// Starts a new Chrome instance on the profile; Chrome hands the URL to the
    /// running one, which opens it in that profile's window.
    private func open(_ url: URL, in profile: PTTChromeProfile) {
        guard let chrome = NSWorkspace.shared.urlForApplication(withBundleIdentifier: PTTChromeProfiles.bundleID) else {
            Self.logger.error("Chrome is not installed; opening in the default browser")
            NSWorkspace.shared.open(url)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = PTTChromeProfiles.launchArguments(profile: profile, url: url)
        NSWorkspace.shared.openApplication(at: chrome, configuration: configuration) { _, error in
            if let error {
                Self.logger.error("Could not open Chrome: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
