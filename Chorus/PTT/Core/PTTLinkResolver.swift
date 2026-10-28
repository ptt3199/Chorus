import Foundation

/// What to do with a link that leaves Chorus, and why. Pure: callers gather
/// the inputs and act on the result.
struct PTTLinkResolution: Equatable, Sendable {
    enum Branch: Equatable, Sendable {
        /// (a) A Chorus service owns the link: keep Chorus's own behaviour.
        case chorusService
        /// (b) A rule matched.
        case rule(PTTLinkRule)
        /// (c) The source service has a default profile.
        case serviceProfile
        /// (d) Nothing applies: keep Chorus's own behaviour.
        case fallback
    }

    enum Target: Equatable, Sendable {
        /// Do what Chorus did before the fork (switch service, default
        /// browser, in-app window — whatever the caller would have done).
        case unchanged
        /// Open `url` in this Chrome profile.
        case chrome(PTTChromeProfile)
        /// A profile was chosen by name but Chrome has no such profile: log
        /// it and open in the default browser.
        case missingProfile(String)
    }

    /// The link as clicked.
    var originalURL: URL
    /// The link to open: redirect unwrapped and, for a Chrome target whose
    /// profile has an email, `authuser` added.
    var url: URL
    var branch: Branch
    var target: Target

    /// The profile name the decision picked, if any (from the rule or the
    /// service).
    var profileName: String? {
        switch target {
        case .unchanged: return nil
        case .chrome(let profile): return profile.name
        case .missingProfile(let name): return name
        }
    }
}

enum PTTLinkResolver {
    /// Decides how to open `url`.
    ///
    /// 1. Unwrap the redirect (`PTTURLRewriting.unwrapRedirect`). Everything
    ///    below uses the unwrapped URL.
    /// 2. (a) `isOwnedByChorusService(unwrapped)` → `.chorusService`,
    ///    `.unchanged`, `url` = the original URL (Chorus handles it as before).
    /// 3. (b) First matching rule → `.rule(rule)`, profile = `rule.profile`.
    /// 4. (c) `serviceProfile` non-nil and non-empty → `.serviceProfile`.
    /// 5. (d) Otherwise `.fallback`, `.unchanged`, `url` = unwrapped URL.
    /// For (b) and (c): look the name up with `PTTChromeProfiles.find`.
    /// Found → `.chrome(profile)` and `url` = unwrapped URL with
    /// `PTTURLRewriting.addingAuthUser(email: profile.email)`. Not found →
    /// `.missingProfile(name)` and `url` = unwrapped URL.
    /// Only http and https URLs are routed; any other scheme returns
    /// `.fallback` / `.unchanged` with the original URL.
    static func resolve(
        _ url: URL,
        isOwnedByChorusService: (URL) -> Bool,
        serviceProfile: String?,
        rules: PTTRuleSet,
        profiles: [PTTChromeProfile]
    ) -> PTTLinkResolution {
        func result(_ branch: PTTLinkResolution.Branch, _ target: PTTLinkResolution.Target,
                    _ resolved: URL) -> PTTLinkResolution {
            PTTLinkResolution(originalURL: url, url: resolved, branch: branch, target: target)
        }

        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return result(.fallback, .unchanged, url)
        }
        let unwrapped = PTTURLRewriting.unwrapRedirect(url)

        if isOwnedByChorusService(unwrapped) {
            return result(.chorusService, .unchanged, url)
        }

        let branch: PTTLinkResolution.Branch
        let name: String
        if let rule = rules.firstMatch(for: unwrapped) {
            branch = .rule(rule)
            name = rule.profile
        } else if let serviceProfile, !serviceProfile.isEmpty {
            branch = .serviceProfile
            name = serviceProfile
        } else {
            return result(.fallback, .unchanged, unwrapped)
        }

        guard let profile = PTTChromeProfiles.find(name, in: profiles) else {
            return result(branch, .missingProfile(name), unwrapped)
        }
        let opened = PTTURLRewriting.addingAuthUser(to: unwrapped, email: profile.email)
        return result(branch, .chrome(profile), opened)
    }
}

/// One line in the in-memory link log Settings shows.
struct PTTLinkLogEntry: Equatable, Identifiable, Sendable {
    var id = UUID()
    var date: Date
    /// The unwrapped URL.
    var url: URL
    var sourceService: String?
    /// A short description of the matched rule, such as `domain youtube.com`.
    var rule: String?
    /// The profile used, or nil when the link kept Chorus's behaviour.
    var profile: String?
}

/// Keeps the most recent entries, newest first, at most `capacity`.
struct PTTLinkLog: Equatable, Sendable {
    static let defaultCapacity = 20

    let capacity: Int
    private(set) var entries: [PTTLinkLogEntry] = []

    init(capacity: Int = PTTLinkLog.defaultCapacity) {
        self.capacity = capacity
    }

    /// Inserts at the front and drops the oldest past `capacity`.
    mutating func record(_ entry: PTTLinkLogEntry) {
        entries.insert(entry, at: 0)
        if entries.count > capacity {
            entries.removeLast(entries.count - max(capacity, 0))
        }
    }

    /// Builds an entry from a resolution: `url` is `resolution.url`, `rule`
    /// is "<kind> <pattern>" for `.rule`, `profile` is `profileName`.
    static func entry(for resolution: PTTLinkResolution, sourceService: String?, date: Date = Date()) -> PTTLinkLogEntry {
        var ruleText: String?
        if case .rule(let rule) = resolution.branch {
            ruleText = "\(rule.kind.rawValue) \(rule.pattern)"
        }
        return PTTLinkLogEntry(
            date: date, url: resolution.url, sourceService: sourceService,
            rule: ruleText, profile: resolution.profileName)
    }
}

/// Each service's default Chrome profile, kept in UserDefaults under
/// `PTT.serviceProfile.<service UUID>` so the SwiftData model is untouched.
struct PTTServiceProfiles: @unchecked Sendable {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func key(for serviceID: UUID) -> String {
        "PTT.serviceProfile.\(serviceID.uuidString)"
    }

    /// The profile name, or nil when unset or empty.
    func profile(for serviceID: UUID) -> String? {
        guard let value = defaults.string(forKey: Self.key(for: serviceID)) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Sets the profile; nil or an empty string removes the key.
    func setProfile(_ name: String?, for serviceID: UUID) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            defaults.removeObject(forKey: Self.key(for: serviceID))
        } else {
            defaults.set(trimmed, forKey: Self.key(for: serviceID))
        }
    }
}
