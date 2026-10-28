import Foundation

/// URL clean-up done before rules are matched and before the link opens.
enum PTTURLRewriting {
    /// Unwraps Google's redirect links: `https://www.google.com/url?q=<target>`
    /// or `...?url=<target>` (host `google.com` or `www.google.com`, path
    /// `/url`). Unwraps repeatedly (a redirect inside a redirect), at most 5
    /// times. Returns `url` unchanged when it is not such a redirect, or when
    /// the target is missing or not an http/https URL.
    static func unwrapRedirect(_ url: URL) -> URL {
        fatalError("TODO")
    }

    /// The Google hosts that take `authuser`: docs, drive, meet, sheets and
    /// slides `.google.com`.
    static let authUserHosts: Set<String> = [
        "docs.google.com", "drive.google.com", "meet.google.com",
        "sheets.google.com", "slides.google.com",
    ]

    /// Adds `authuser=<email>` to a link on one of `authUserHosts` so it opens
    /// in the matching Google account. Leaves `url` unchanged when `email` is
    /// nil or empty, the host is not in the set, or the query already has an
    /// `authuser` item (any value). Keeps the existing query and fragment.
    static func addingAuthUser(to url: URL, email: String?) -> URL {
        fatalError("TODO")
    }
}
