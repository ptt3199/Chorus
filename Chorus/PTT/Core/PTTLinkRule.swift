import Foundation

/// One user rule: links that match `pattern` open in the Chrome profile named
/// `profile` (the display name Chrome shows, such as "ONE").
struct PTTLinkRule: Codable, Equatable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable {
        /// `pattern` is a host such as `youtube.com`. Matches that host and
        /// every subdomain of it (`www.youtube.com`, `m.youtube.com`), and
        /// nothing else (`notyoutube.com` does not match). Case-insensitive.
        case domain
        /// `pattern` is a glob where `*` matches any run of characters
        /// (including none) and `?` matches one character. Case-insensitive.
        /// Without a `/` the glob is matched against the whole host
        /// (`*.atlassian.net` matches `acme.atlassian.net`, not
        /// `atlassian.net`). With a `/` it is matched against
        /// `host + path` (`github.com/acme/*`).
        case wildcard
        /// `pattern` is an `NSRegularExpression`, searched (not anchored)
        /// in the URL's `absoluteString`. Case-insensitive. An invalid
        /// pattern never matches.
        case regex
    }

    var id: UUID
    var kind: Kind
    var pattern: String
    var profile: String

    init(id: UUID = UUID(), kind: Kind, pattern: String, profile: String) {
        self.id = id
        self.kind = kind
        self.pattern = pattern
        self.profile = profile
    }

    /// Whether this rule matches `url`. A URL with no host never matches
    /// a domain or wildcard rule. Surrounding whitespace in `pattern` is
    /// ignored; an empty pattern never matches.
    func matches(_ url: URL) -> Bool {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        switch kind {
        case .domain:
            guard let host = Self.normalizedHost(of: url) else { return false }
            let target = Self.stripTrailingDot(trimmed.lowercased())
            guard !target.isEmpty else { return false }
            return host == target || host.hasSuffix("." + target)
        case .wildcard:
            guard let host = Self.normalizedHost(of: url) else { return false }
            let subject: String
            if trimmed.contains("/") {
                let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path ?? url.path
                subject = host + path
            } else {
                subject = host
            }
            guard let regex = Self.wildcardRegex(trimmed) else { return false }
            return Self.fullyMatches(regex, subject)
        case .regex:
            guard let regex = try? NSRegularExpression(pattern: trimmed, options: [.caseInsensitive]) else {
                return false
            }
            let subject = url.absoluteString
            return regex.firstMatch(
                in: subject, options: [],
                range: NSRange(subject.startIndex..., in: subject)) != nil
        }
    }

    /// Whether `pattern` is usable for its kind (non-empty; a regex that
    /// compiles). Shown in Settings next to a broken rule.
    var isValid: Bool {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if kind == .regex {
            return (try? NSRegularExpression(pattern: trimmed, options: [.caseInsensitive])) != nil
        }
        return true
    }

    private static func stripTrailingDot(_ host: String) -> String {
        host.hasSuffix(".") ? String(host.dropLast()) : host
    }

    private static func normalizedHost(of url: URL) -> String? {
        guard let host = url.host, !host.isEmpty else { return nil }
        let result = stripTrailingDot(host.lowercased())
        return result.isEmpty ? nil : result
    }

    private static func wildcardRegex(_ glob: String) -> NSRegularExpression? {
        var body = ""
        for character in glob {
            switch character {
            case "*": body += ".*"
            case "?": body += "."
            default: body += NSRegularExpression.escapedPattern(for: String(character))
            }
        }
        return try? NSRegularExpression(
            pattern: "^" + body + "$", options: [.caseInsensitive, .dotMatchesLineSeparators])
    }

    private static func fullyMatches(_ regex: NSRegularExpression, _ subject: String) -> Bool {
        regex.firstMatch(
            in: subject, options: [],
            range: NSRange(subject.startIndex..., in: subject)) != nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, pattern, profile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.kind = try container.decode(Kind.self, forKey: .kind)
        self.pattern = try container.decode(String.self, forKey: .pattern)
        self.profile = try container.decode(String.self, forKey: .profile)
    }
}

/// The ordered rule list. The first matching rule wins.
struct PTTRuleSet: Codable, Equatable, Sendable {
    /// Bumped only if the file format changes shape.
    var version: Int = 1
    var rules: [PTTLinkRule]

    init(version: Int = 1, rules: [PTTLinkRule]) {
        self.version = version
        self.rules = rules
    }

    /// The first rule that matches `url`, or nil.
    func firstMatch(for url: URL) -> PTTLinkRule? {
        rules.first { $0.matches(url) }
    }

    private enum CodingKeys: String, CodingKey {
        case version, rules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.rules = try container.decode([PTTLinkRule].self, forKey: .rules)
    }

    /// The rules a new install starts with:
    /// youtube.com → personal, facebook.com → personal (both `.domain`),
    /// *.atlassian.net → ONE (`.wildcard`).
    static let defaults: PTTRuleSet = {
        PTTRuleSet(rules: [
            PTTLinkRule(kind: .domain, pattern: "youtube.com", profile: "personal"),
            PTTLinkRule(kind: .domain, pattern: "facebook.com", profile: "personal"),
            PTTLinkRule(kind: .wildcard, pattern: "*.atlassian.net", profile: "ONE"),
        ])
    }()

    /// Decodes the JSON rule file. Throws on malformed JSON. Keys are
    /// `version` and `rules`; each rule has `id` (optional in the file — a
    /// missing id gets a fresh UUID), `kind`, `pattern`, `profile`.
    static func decode(_ data: Data) throws -> PTTRuleSet {
        try JSONDecoder().decode(PTTRuleSet.self, from: data)
    }

    /// Pretty-printed JSON with sorted keys, so the file reads well and diffs
    /// cleanly when edited by hand.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// Adds a `.domain` rule for `host` (with a leading `www.` dropped) at the
    /// front of the list, so it wins over older rules. Replaces an existing
    /// `.domain` rule with the same pattern instead of adding a second.
    mutating func prependDomainRule(host: String, profile: String) {
        var pattern = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if pattern.lowercased().hasPrefix("www.") {
            pattern = String(pattern.dropFirst(4))
        }
        rules.removeAll { $0.kind == .domain && $0.pattern.lowercased() == pattern.lowercased() }
        rules.insert(PTTLinkRule(kind: .domain, pattern: pattern, profile: profile), at: 0)
    }
}
