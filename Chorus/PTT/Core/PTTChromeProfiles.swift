import Foundation

/// A Chrome profile as `Local State` describes it.
struct PTTChromeProfile: Equatable, Hashable, Sendable {
    /// The folder under the Chrome data dir, such as `Default` or `Profile 3`.
    /// This is what `--profile-directory` takes.
    var directory: String
    /// The name Chrome shows, such as `ONE`. Rules refer to profiles by this.
    var name: String
    /// The signed-in Google account, if any (`user_name` in Local State).
    var email: String?
}

enum PTTChromeProfiles {
    /// Chrome's bundle id, used to find and launch it.
    static let bundleID = "com.google.Chrome"

    /// `~/Library/Application Support/Google/Chrome/Local State`.
    static var localStateURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/Google/Chrome/Local State")
    }

    /// Parses Local State JSON: `profile.info_cache` maps each directory to
    /// an object with `name` and `user_name` (an empty `user_name` means no
    /// email). Throws on malformed JSON or when `profile.info_cache` is
    /// missing. Result is sorted by `name` (case-insensitive).
    static func parse(localState data: Data) throws -> [PTTChromeProfile] {
        fatalError("TODO")
    }

    /// Reads and parses the file at `url`. Returns `[]` when the file is
    /// missing or cannot be parsed (never throws).
    static func load(from url: URL = localStateURL) -> [PTTChromeProfile] {
        fatalError("TODO")
    }

    /// The profile whose display name equals `name` (case-insensitive,
    /// surrounding whitespace ignored). Falls back to a profile whose
    /// `directory` equals `name`, so `Default` also works. Nil when none.
    static func find(_ name: String, in profiles: [PTTChromeProfile]) -> PTTChromeProfile? {
        fatalError("TODO")
    }

    /// The arguments Chrome is launched with:
    /// `["--profile-directory=<directory>", url.absoluteString]`.
    static func launchArguments(profile: PTTChromeProfile, url: URL) -> [String] {
        fatalError("TODO")
    }
}
