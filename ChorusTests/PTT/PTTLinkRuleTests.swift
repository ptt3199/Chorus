import XCTest
@testable import Chorus

final class PTTLinkRuleTests: XCTestCase {
    private func rule(_ kind: PTTLinkRule.Kind, _ pattern: String, _ profile: String = "P") -> PTTLinkRule {
        PTTLinkRule(kind: kind, pattern: pattern, profile: profile)
    }

    private func url(_ string: String) -> URL { URL(string: string)! }

    func testDomainMatchesHostAndSubdomains() {
        let r = rule(.domain, "youtube.com")
        XCTAssertTrue(r.matches(url("https://youtube.com/watch")))
        XCTAssertTrue(r.matches(url("https://www.youtube.com/watch")))
        XCTAssertTrue(r.matches(url("https://m.youtube.com")))
    }

    func testDomainRejectsLookAlikes() {
        let r = rule(.domain, "youtube.com")
        XCTAssertFalse(r.matches(url("https://notyoutube.com")))
        XCTAssertFalse(r.matches(url("https://youtube.com.evil.org")))
        XCTAssertFalse(r.matches(url("https://example.com/youtube.com")))
    }

    func testDomainIgnoresTrailingDotAndCase() {
        let r = rule(.domain, "YouTube.com")
        XCTAssertTrue(r.matches(url("https://WWW.YOUTUBE.COM/")))
        XCTAssertTrue(r.matches(url("https://youtube.com./")))
    }

    func testWildcardHostOnly() {
        let r = rule(.wildcard, "*.atlassian.net")
        XCTAssertTrue(r.matches(url("https://acme.atlassian.net/browse/X-1")))
        XCTAssertFalse(r.matches(url("https://atlassian.net")))
    }

    func testWildcardWithPath() {
        let r = rule(.wildcard, "github.com/acme/*")
        XCTAssertTrue(r.matches(url("https://github.com/acme/repo")))
        XCTAssertTrue(r.matches(url("https://GitHub.com/Acme/repo/issues")))
        XCTAssertFalse(r.matches(url("https://github.com/other/repo")))
        XCTAssertFalse(r.matches(url("https://gist.github.com/acme/repo")))
    }

    func testWildcardQuestionMarkAndEscaping() {
        XCTAssertTrue(rule(.wildcard, "a?.example.com").matches(url("https://ab.example.com")))
        XCTAssertFalse(rule(.wildcard, "a?.example.com").matches(url("https://abc.example.com")))
        XCTAssertFalse(rule(.wildcard, "example.com").matches(url("https://exampleXcom")))
    }

    func testRegexSearchesAbsoluteString() {
        let r = rule(.regex, "docs\\.google\\.com/.*/edit")
        XCTAssertTrue(r.matches(url("https://docs.google.com/document/d/1/edit")))
        XCTAssertTrue(r.matches(url("HTTPS://DOCS.GOOGLE.COM/x/edit")))
        XCTAssertFalse(r.matches(url("https://docs.google.com/document/d/1/view")))
    }

    func testInvalidRegexNeverMatches() {
        let r = rule(.regex, "([unclosed")
        XCTAssertFalse(r.isValid)
        XCTAssertFalse(r.matches(url("https://example.com/([unclosed")))
    }

    func testEmptyPattern() {
        for kind in PTTLinkRule.Kind.allCases {
            let r = rule(kind, "   ")
            XCTAssertFalse(r.isValid)
            XCTAssertFalse(r.matches(url("https://example.com")))
        }
    }

    func testValidRules() {
        XCTAssertTrue(rule(.domain, "a.com").isValid)
        XCTAssertTrue(rule(.wildcard, "*.a.com").isValid)
        XCTAssertTrue(rule(.regex, "a+").isValid)
    }

    func testNoHostNeverMatchesDomainOrWildcard() {
        let u = url("mailto:someone@example.com")
        XCTAssertFalse(rule(.domain, "example.com").matches(u))
        XCTAssertFalse(rule(.wildcard, "*").matches(u))
    }

    func testFirstMatchWinsAndNoMatchIsNil() {
        let first = rule(.domain, "example.com", "A")
        let second = rule(.wildcard, "*.example.com", "B")
        let set = PTTRuleSet(rules: [first, second])
        XCTAssertEqual(set.firstMatch(for: url("https://www.example.com"))?.profile, "A")
        XCTAssertNil(set.firstMatch(for: url("https://other.org")))
    }

    func testJSONRoundTrip() throws {
        let set = PTTRuleSet(rules: [rule(.domain, "a.com", "X"), rule(.regex, "b/c", "Y")])
        let decoded = try PTTRuleSet.decode(try set.encoded())
        XCTAssertEqual(decoded, set)
    }

    func testDecodeMissingIdAndVersion() throws {
        let json = #"{"rules":[{"kind":"domain","pattern":"a.com","profile":"X"}]}"#
        let set = try PTTRuleSet.decode(Data(json.utf8))
        XCTAssertEqual(set.version, 1)
        XCTAssertEqual(set.rules.count, 1)
        XCTAssertEqual(set.rules[0].pattern, "a.com")
    }

    func testDecodeMalformedThrows() {
        XCTAssertThrowsError(try PTTRuleSet.decode(Data("not json".utf8)))
        XCTAssertThrowsError(try PTTRuleSet.decode(Data(#"{"rules":[{"kind":"bogus","pattern":"a","profile":"b"}]}"#.utf8)))
    }

    func testPrependDomainRule() {
        var set = PTTRuleSet(rules: [rule(.domain, "old.com", "A"), rule(.domain, "example.com", "B")])
        set.prependDomainRule(host: "www.example.com", profile: "C")
        XCTAssertEqual(set.rules.count, 2)
        XCTAssertEqual(set.rules[0].kind, .domain)
        XCTAssertEqual(set.rules[0].pattern, "example.com")
        XCTAssertEqual(set.rules[0].profile, "C")
        XCTAssertEqual(set.rules[1].pattern, "old.com")
    }

    func testPrependDomainRuleKeepsOtherKinds() {
        var set = PTTRuleSet(rules: [rule(.wildcard, "example.com", "A")])
        set.prependDomainRule(host: "example.com", profile: "C")
        XCTAssertEqual(set.rules.count, 2)
        XCTAssertEqual(set.rules[0].kind, .domain)
    }

    func testDefaults() {
        let rules = PTTRuleSet.defaults.rules
        XCTAssertEqual(rules.count, 3)
        XCTAssertEqual(rules[0].kind, .domain)
        XCTAssertEqual(rules[0].pattern, "youtube.com")
        XCTAssertEqual(rules[0].profile, "personal")
        XCTAssertEqual(rules[1].kind, .domain)
        XCTAssertEqual(rules[1].pattern, "facebook.com")
        XCTAssertEqual(rules[1].profile, "personal")
        XCTAssertEqual(rules[2].kind, .wildcard)
        XCTAssertEqual(rules[2].pattern, "*.atlassian.net")
        XCTAssertEqual(rules[2].profile, "ONE")
    }
}
