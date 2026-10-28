import XCTest
@testable import Chorus

final class PTTURLRewritingTests: XCTestCase {
    private func u(_ s: String) -> URL { URL(string: s)! }

    func testPlainURLUnchanged() {
        let url = u("https://example.com/a?b=c")
        XCTAssertEqual(PTTURLRewriting.unwrapRedirect(url), url)
    }

    func testQRedirect() {
        let url = u("https://www.google.com/url?q=https://example.com/page")
        XCTAssertEqual(PTTURLRewriting.unwrapRedirect(url), u("https://example.com/page"))
    }

    func testURLRedirect() {
        let url = u("https://www.google.com/url?url=https://example.com/page")
        XCTAssertEqual(PTTURLRewriting.unwrapRedirect(url), u("https://example.com/page"))
    }

    func testBothHosts() {
        XCTAssertEqual(PTTURLRewriting.unwrapRedirect(u("https://google.com/url?q=https://a.com")), u("https://a.com"))
        XCTAssertEqual(PTTURLRewriting.unwrapRedirect(u("https://WWW.Google.com/url?q=https://a.com")), u("https://a.com"))
    }

    func testNestedRedirect() {
        let inner = "https%3A%2F%2Fwww.google.com%2Furl%3Fq%3Dhttps%3A%2F%2Fexample.com%2Fend"
        let url = u("https://www.google.com/url?q=\(inner)")
        XCTAssertEqual(PTTURLRewriting.unwrapRedirect(url), u("https://example.com/end"))
    }

    func testNonHTTPTargetUnchanged() {
        let url = u("https://www.google.com/url?q=javascript:alert(1)")
        XCTAssertEqual(PTTURLRewriting.unwrapRedirect(url), url)
    }

    func testOtherPathUnchanged() {
        let url = u("https://www.google.com/search?q=https://example.com")
        XCTAssertEqual(PTTURLRewriting.unwrapRedirect(url), url)
    }

    func testEncodedTargetKeepsItsQuery() {
        let url = u("https://www.google.com/url?q=https%3A%2F%2Fexample.com%2Fp%3Fa%3D1%26b%3D2&sa=D")
        XCTAssertEqual(PTTURLRewriting.unwrapRedirect(url), u("https://example.com/p?a=1&b=2"))
    }

    func testAuthUserAddedOnGoogleHosts() {
        for host in ["docs", "drive", "meet", "sheets", "slides"] {
            let url = u("https://\(host).google.com/x")
            XCTAssertEqual(PTTURLRewriting.addingAuthUser(to: url, email: "me@x.com"),
                           u("https://\(host).google.com/x?authuser=me%40x.com"), host)
        }
    }

    func testAuthUserNotAddedElsewhere() {
        for s in ["https://mail.google.com/mail", "https://example.com/x"] {
            XCTAssertEqual(PTTURLRewriting.addingAuthUser(to: u(s), email: "me@x.com"), u(s))
        }
    }

    func testAuthUserNotAddedWhenPresent() {
        let url = u("https://docs.google.com/x?authuser=2")
        XCTAssertEqual(PTTURLRewriting.addingAuthUser(to: url, email: "me@x.com"), url)
    }

    func testNilOrEmptyEmail() {
        let url = u("https://docs.google.com/x")
        XCTAssertEqual(PTTURLRewriting.addingAuthUser(to: url, email: nil), url)
        XCTAssertEqual(PTTURLRewriting.addingAuthUser(to: url, email: ""), url)
    }

    func testKeepsQueryAndFragment() {
        let url = u("https://docs.google.com/d?a=1&b=2#heading")
        XCTAssertEqual(PTTURLRewriting.addingAuthUser(to: url, email: "me@x.com"),
                       u("https://docs.google.com/d?a=1&b=2&authuser=me%40x.com#heading"))
    }

    func testPlusInEmailSurvives() {
        let result = PTTURLRewriting.addingAuthUser(to: u("https://docs.google.com/d"), email: "a+b@x.com")
        XCTAssertEqual(result.absoluteString, "https://docs.google.com/d?authuser=a%2Bb%40x.com")
        let items = URLComponents(url: result, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(items?.first?.value, "a+b@x.com")
    }
}
