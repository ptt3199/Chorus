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
        let root = try JSONSerialization.jsonObject(with: data)
        guard let dict = root as? [String: Any],
              let profile = dict["profile"] as? [String: Any],
              let cache = profile["info_cache"] as? [String: Any] else {
            throw ParseError.missingInfoCache
        }
        var result: [PTTChromeProfile] = []
        for (directory, value) in cache {
            guard let entry = value as? [String: Any],
                  let name = entry["name"] as? String else { continue }
            let email = (entry["user_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            result.append(PTTChromeProfile(directory: directory, name: name, email: email))
        }
        return result.sorted {
            let order = $0.name.caseInsensitiveCompare($1.name)
            if order != .orderedSame { return order == .orderedAscending }
            return $0.directory < $1.directory
        }
    }

    enum ParseError: Error {
        case missingInfoCache
    }

    /// Reads and parses the file at `url`. Returns `[]` when the file is
    /// missing or cannot be parsed (never throws).
    static func load(from url: URL = localStateURL) -> [PTTChromeProfile] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? parse(localState: data)) ?? []
    }

    /// The profile whose display name equals `name` (case-insensitive,
    /// surrounding whitespace ignored). Falls back to a profile whose
    /// `directory` equals `name`, so `Default` also works. Nil when none.
    static func find(_ name: String, in profiles: [PTTChromeProfile]) -> PTTChromeProfile? {
        let wanted = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = profiles.first(where: {
            $0.name.caseInsensitiveCompare(wanted) == .orderedSame
        }) {
            return match
        }
        return profiles.first { $0.directory == wanted }
    }

    /// The arguments Chrome is launched with:
    /// `["--profile-directory=<directory>", url.absoluteString]`.
    static func launchArguments(profile: PTTChromeProfile, url: URL) -> [String] {
        ["--profile-directory=\(profile.directory)", url.absoluteString]
    }
}
