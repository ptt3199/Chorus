# Task 01 — Link rules and rule set

## Goal
Implement everything marked `fatalError("TODO")` in `Chorus/PTT/Core/PTTLinkRule.swift` exactly as the doc comments there describe, and write unit tests.

## Files you may edit
- `Chorus/PTT/Core/PTTLinkRule.swift`
- `ChorusTests/PTT/PTTLinkRuleTests.swift` (new)

## API
Foundation only: `URL`, `URLComponents`, `NSRegularExpression` (`.caseInsensitive`), `JSONEncoder` (`.prettyPrinted, .sortedKeys, .withoutEscapingSlashes`), `JSONDecoder`.
- Wildcard: convert the glob to an anchored regular expression (escape everything with `NSRegularExpression.escapedPattern(for:)`, then `*` → `.*`, `?` → `.`), case-insensitive.
- Domain: compare lowercased host; trailing dot in host ignored.
- `PTTRuleSet.decode`: rules whose `id` is missing in JSON get `UUID()`. Implement a custom `init(from:)` on `PTTLinkRule` for that (still `Codable`). `version` missing → 1.
- `defaults`: three rules in this order: domain youtube.com → personal, domain facebook.com → personal, wildcard *.atlassian.net → ONE.

## Done when
Tests cover at least: each kind matching and not matching (domain subdomain yes, look-alike `notyoutube.com` no; wildcard `*.atlassian.net` vs `atlassian.net`; wildcard with path; regex match; invalid regex never matches and `isValid == false`; empty pattern), case-insensitivity, rule order (first match wins when two match), URL with no match returns nil, JSON round trip, decode with missing id, decode malformed JSON throws, `prependDomainRule` (strips `www.`, goes first, replaces duplicate), and `defaults` content.
`swift build --package-path scripts/ptt-core-tests --target Chorus` passes.
