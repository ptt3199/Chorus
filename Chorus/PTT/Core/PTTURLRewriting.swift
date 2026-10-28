import Foundation

/// URL clean-up done before rules are matched and before the link opens.
enum PTTURLRewriting {
    /// Unwraps Google's redirect links: `https://www.google.com/url?q=<target>`
    /// or `...?url=<target>` (host `google.com` or `www.google.com`, path
    /// `/url`). Unwraps repeatedly (a redirect inside a redirect), at most 5
    /// times. Returns `url` unchanged when it is not such a redirect, or when
    /// the target is missing or not an http/https URL.
    static func unwrapRedirect(_ url: URL) -> URL {
        var current = url
        for _ in 0..<5 {
            guard let target = redirectTarget(of: current) else { break }
            current = target
        }
        return current
    }

    /// The http/https target of one Google redirect link, or nil.
    private static func redirectTarget(of url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased(),
              host == "google.com" || host == "www.google.com",
              components.path == "/url",
              let items = components.queryItems else { return nil }
        for name in ["q", "url"] {
            guard let value = items.first(where: { $0.name == name })?.value,
                  let target = URL(string: value),
                  let scheme = target.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else { continue }
            return target
        }
        return nil
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
        guard let email, !email.isEmpty,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased(),
              authUserHosts.contains(host) else { return url }
        var items = components.percentEncodedQueryItems ?? []
        if items.contains(where: { $0.name.lowercased() == "authuser" }) { return url }
        // Encode everything but unreserved characters so `+` and `@` survive.
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let encoded = email.addingPercentEncoding(withAllowedCharacters: allowed) else { return url }
        items.append(URLQueryItem(name: "authuser", value: encoded))
        components.percentEncodedQueryItems = items
        return components.url ?? url
    }
}
