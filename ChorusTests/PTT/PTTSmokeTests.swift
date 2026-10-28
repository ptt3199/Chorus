import XCTest
@testable import Chorus

final class PTTSmokeTests: XCTestCase {
    func testIdentityNamesDifferFromOriginalChorus() {
        XCTAssertEqual(PTTAppIdentity.storeFolder, "Chorus PTT")
        XCTAssertEqual(PTTAppIdentity.debugStoreFolder, "Chorus PTT-debug")
    }
}
