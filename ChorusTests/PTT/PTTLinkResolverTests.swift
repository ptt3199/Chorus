import XCTest
@testable import Chorus

final class PTTLinkResolverTests: XCTestCase {
    private let one = PTTChromeProfile(directory: "Profile 1", name: "ONE", email: "me@one.com")
    private let personal = PTTChromeProfile(directory: "Default", name: "personal", email: nil)
    private var profiles: [PTTChromeProfile] { [one, personal] }

    private func resolve(
        _ string: String,
        owned: Bool = false,
        serviceProfile: String? = nil,
        rules: PTTRuleSet = .defaults
    ) -> PTTLinkResolution {
        PTTLinkResolver.resolve(
            URL(string: string)!,
            isOwnedByChorusService: { _ in owned },
            serviceProfile: serviceProfile,
            rules: rules,
            profiles: profiles)
    }

    func testOwnedByChorusServiceWinsOverRule() {
        let url = "https://youtube.com/watch?v=1"
        let result = resolve(url, owned: true, serviceProfile: "ONE")
        XCTAssertEqual(result.branch, .chorusService)
        XCTAssertEqual(result.target, .unchanged)
        XCTAssertEqual(result.url, URL(string: url)!)
    }

    func testOwnershipIsCheckedOnUnwrappedURL() {
        var seen: URL?
        let result = PTTLinkResolver.resolve(
            URL(string: "https://www.google.com/url?q=https://example.com/a")!,
            isOwnedByChorusService: { seen = $0; return true },
            serviceProfile: nil, rules: .defaults, profiles: profiles)
        XCTAssertEqual(seen, URL(string: "https://example.com/a"))
        XCTAssertEqual(result.url, URL(string: "https://www.google.com/url?q=https://example.com/a")!)
    }

    func testRuleWinsOverServiceProfile() {
        let result = resolve("https://www.youtube.com/watch?v=1", serviceProfile: "ONE")
        guard case .rule(let rule) = result.branch else { return XCTFail("expected rule") }
        XCTAssertEqual(rule.pattern, "youtube.com")
        XCTAssertEqual(result.target, .chrome(personal))
        XCTAssertEqual(result.profileName, "personal")
    }

    func testServiceProfileUsedWhenNoRule() {
        let result = resolve("https://example.com/x", serviceProfile: "ONE")
        XCTAssertEqual(result.branch, .serviceProfile)
        XCTAssertEqual(result.target, .chrome(one))
    }

    func testDriveLinkFallsToServiceProfileAndGetsAuthUser() {
        let result = resolve("https://drive.google.com/file/d/1/view", serviceProfile: "ONE")
        XCTAssertEqual(result.branch, .serviceProfile)
        XCTAssertEqual(result.target, .chrome(one))
        XCTAssertEqual(result.url.absoluteString, "https://drive.google.com/file/d/1/view?authuser=me%40one.com")
    }

    func testNoRuleAndNoServiceProfileFallsBack() {
        let result = resolve("https://example.com/x")
        XCTAssertEqual(result.branch, .fallback)
        XCTAssertEqual(result.target, .unchanged)
        XCTAssertEqual(result.url, URL(string: "https://example.com/x")!)
        XCTAssertNil(result.profileName)
    }

    func testEmptyServiceProfileIsTreatedAsNil() {
        let result = resolve("https://example.com/x", serviceProfile: "")
        XCTAssertEqual(result.branch, .fallback)
    }

    func testRedirectIsUnwrappedBeforeRuleMatching() {
        let result = resolve("https://www.google.com/url?q=https://youtube.com/watch?v=1")
        guard case .rule = result.branch else { return XCTFail("expected rule") }
        XCTAssertEqual(result.url, URL(string: "https://youtube.com/watch?v=1")!)
        XCTAssertEqual(result.originalURL.host, "www.google.com")
    }

    func testMissingProfile() {
        let result = resolve("https://example.com/x", serviceProfile: "Nope")
        XCTAssertEqual(result.branch, .serviceProfile)
        XCTAssertEqual(result.target, .missingProfile("Nope"))
        XCTAssertEqual(result.profileName, "Nope")
        XCTAssertEqual(result.url, URL(string: "https://example.com/x")!)
    }

    func testExistingAuthUserIsKept() {
        let url = "https://docs.google.com/document/d/1?authuser=2"
        let result = resolve(url, serviceProfile: "ONE")
        XCTAssertEqual(result.url, URL(string: url)!)
    }

    func testNonHTTPSchemeFallsBack() {
        let result = resolve("mailto:a@b.com", serviceProfile: "ONE")
        XCTAssertEqual(result.branch, .fallback)
        XCTAssertEqual(result.target, .unchanged)
        XCTAssertEqual(result.url, URL(string: "mailto:a@b.com")!)
    }

    // MARK: Log

    private func entry(_ n: Int) -> PTTLinkLogEntry {
        PTTLinkLogEntry(
            date: Date(timeIntervalSince1970: Double(n)),
            url: URL(string: "https://example.com/\(n)")!,
            sourceService: nil, rule: nil, profile: nil)
    }

    func testLogKeepsNewestFirstAndCapsAtTwenty() {
        var log = PTTLinkLog()
        for n in 0..<25 { log.record(entry(n)) }
        XCTAssertEqual(log.entries.count, 20)
        XCTAssertEqual(log.entries.first?.url.lastPathComponent, "24")
        XCTAssertEqual(log.entries.last?.url.lastPathComponent, "5")
    }

    func testLogEntryFieldsForRule() {
        let result = resolve("https://youtube.com/watch")
        let date = Date(timeIntervalSince1970: 42)
        let logged = PTTLinkLog.entry(for: result, sourceService: "Slack", date: date)
        XCTAssertEqual(logged.date, date)
        XCTAssertEqual(logged.url, result.url)
        XCTAssertEqual(logged.sourceService, "Slack")
        XCTAssertEqual(logged.rule, "domain youtube.com")
        XCTAssertEqual(logged.profile, "personal")
    }

    func testLogEntryFieldsForFallback() {
        let logged = PTTLinkLog.entry(for: resolve("https://example.com"), sourceService: nil)
        XCTAssertNil(logged.rule)
        XCTAssertNil(logged.profile)
        XCTAssertNil(logged.sourceService)
    }

    // MARK: Service profiles

    func testServiceProfileSetGetClear() {
        let suite = "PTTTests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PTTServiceProfiles(defaults: defaults)
        let id = UUID()

        XCTAssertNil(store.profile(for: id))
        store.setProfile(" ONE ", for: id)
        XCTAssertEqual(store.profile(for: id), "ONE")
        XCTAssertEqual(defaults.string(forKey: PTTServiceProfiles.key(for: id)), "ONE")
        store.setProfile("", for: id)
        XCTAssertNil(store.profile(for: id))
        XCTAssertNil(defaults.object(forKey: PTTServiceProfiles.key(for: id)))
        store.setProfile("ONE", for: id)
        store.setProfile(nil, for: id)
        XCTAssertNil(store.profile(for: id))
    }
}
