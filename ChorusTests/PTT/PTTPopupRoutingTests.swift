import XCTest
@testable import Chorus

final class PTTPopupRoutingTests: XCTestCase {
    private func consider(
        isPopup: Bool = true, isMainFrame: Bool = true, targetIsWeb: Bool = true,
        leavesService: Bool = true, targetIsSignIn: Bool = false, currentPageIsSignIn: Bool = false
    ) -> Bool {
        PTTPopupRouting.shouldConsider(
            isPopup: isPopup, isMainFrame: isMainFrame, targetIsWeb: targetIsWeb,
            leavesService: leavesService, targetIsSignIn: targetIsSignIn,
            currentPageIsSignIn: currentPageIsSignIn)
    }

    func testDocsLinkInPopupIsConsidered() {
        XCTAssertTrue(consider())
    }

    func testEachGuardRefuses() {
        XCTAssertFalse(consider(isPopup: false))
        XCTAssertFalse(consider(isMainFrame: false))
        XCTAssertFalse(consider(targetIsWeb: false))
        XCTAssertFalse(consider(leavesService: false))
        XCTAssertFalse(consider(targetIsSignIn: true))
        XCTAssertFalse(consider(currentPageIsSignIn: true))
    }

    func testBlankPopup() {
        XCTAssertTrue(PTTPopupRouting.isBlank(nil))
        XCTAssertTrue(PTTPopupRouting.isBlank(URL(string: "about:blank")))
        XCTAssertFalse(PTTPopupRouting.isBlank(URL(string: "https://docs.google.com/spreadsheets/d/x")))
    }
}
