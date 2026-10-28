import XCTest
@testable import Chorus

final class PTTChromeProfilesTests: XCTestCase {
    private let sample = """
    { "other": 1, "profile": { "info_cache": {
        "Default":   { "name": "personal", "user_name": "me@gmail.com" },
        "Profile 1": { "name": "ONE",      "user_name": "me@one.com" },
        "Profile 3": { "name": "QUAVEO",   "user_name": "" },
        "Profile 9": { "user_name": "x@y.com" } } } }
    """

    private func profiles() throws -> [PTTChromeProfile] {
        try PTTChromeProfiles.parse(localState: Data(sample.utf8))
    }

    func testParseSample() throws {
        let result = try profiles()
        XCTAssertEqual(result.map(\.name), ["ONE", "personal", "QUAVEO"])
        XCTAssertEqual(result.map(\.directory), ["Profile 1", "Default", "Profile 3"])
        XCTAssertEqual(result[0].email, "me@one.com")
        XCTAssertEqual(result[1].email, "me@gmail.com")
        XCTAssertNil(result[2].email)
    }

    func testMalformedJSONThrows() {
        XCTAssertThrowsError(try PTTChromeProfiles.parse(localState: Data("{nope".utf8)))
    }

    func testMissingInfoCacheThrows() {
        XCTAssertThrowsError(try PTTChromeProfiles.parse(localState: Data("{\"profile\":{}}".utf8)))
    }

    func testLoadMissingFileReturnsEmpty() {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ptt-missing-\(UUID().uuidString)")
        XCTAssertEqual(PTTChromeProfiles.load(from: url), [])
    }

    func testLoadCorruptFileReturnsEmpty() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ptt-corrupt-\(UUID().uuidString)")
        try Data("not json".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(PTTChromeProfiles.load(from: url), [])
    }

    func testLoadValidFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ptt-valid-\(UUID().uuidString)")
        try Data(sample.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(PTTChromeProfiles.load(from: url).count, 3)
    }

    func testFindByNameCaseInsensitiveTrimmed() throws {
        let found = PTTChromeProfiles.find("  one \n", in: try profiles())
        XCTAssertEqual(found?.directory, "Profile 1")
    }

    func testFindByDirectory() throws {
        XCTAssertEqual(PTTChromeProfiles.find("Profile 3", in: try profiles())?.name, "QUAVEO")
    }

    func testFindUnknownIsNil() throws {
        XCTAssertNil(PTTChromeProfiles.find("nobody", in: try profiles()))
    }

    func testLaunchArguments() throws {
        let profile = PTTChromeProfile(directory: "Profile 1", name: "ONE", email: nil)
        let url = try XCTUnwrap(URL(string: "https://example.com/a?b=1"))
        XCTAssertEqual(
            PTTChromeProfiles.launchArguments(profile: profile, url: url),
            ["--profile-directory=Profile 1", "https://example.com/a?b=1"])
    }
}
