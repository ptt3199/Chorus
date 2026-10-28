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
        fatalError("TODO")
    }

    /// Whether `pattern` is usable for its kind (non-empty; a regex that
    /// compiles). Shown in Settings next to a broken rule.
    var isValid: Bool {
        fatalError("TODO")
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
        fatalError("TODO")
    }

    /// The rules a new install starts with:
    /// youtube.com → personal, facebook.com → personal (both `.domain`),
    /// *.atlassian.net → ONE (`.wildcard`).
    static let defaults: PTTRuleSet = {
        fatalError("TODO")
    }()

    /// Decodes the JSON rule file. Throws on malformed JSON. Keys are
    /// `version` and `rules`; each rule has `id` (optional in the file — a
    /// missing id gets a fresh UUID), `kind`, `pattern`, `profile`.
    static func decode(_ data: Data) throws -> PTTRuleSet {
        fatalError("TODO")
    }

    /// Pretty-printed JSON with sorted keys, so the file reads well and diffs
    /// cleanly when edited by hand.
    func encoded() throws -> Data {
        fatalError("TODO")
    }

    /// Adds a `.domain` rule for `host` (with a leading `www.` dropped) at the
    /// front of the list, so it wins over older rules. Replaces an existing
    /// `.domain` rule with the same pattern instead of adding a second.
    mutating func prependDomainRule(host: String, profile: String) {
        fatalError("TODO")
    }
}
