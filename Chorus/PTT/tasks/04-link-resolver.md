# Task 04 — Link resolver, link log, service profiles

## Goal
Implement every `fatalError("TODO")` in `Chorus/PTT/Core/PTTLinkResolver.swift` as its doc comments describe, and write unit tests. `PTTLinkRule`, `PTTRuleSet`, `PTTURLRewriting` and `PTTChromeProfiles` are already implemented; use them, do not change them.

## Files you may edit
- `Chorus/PTT/Core/PTTLinkResolver.swift`
- `ChorusTests/PTT/PTTLinkResolverTests.swift` (new)

## API
- `resolve`: follow the numbered steps in its doc comment exactly. `isOwnedByChorusService` is called with the unwrapped URL.
- `PTTLinkLog.record`: insert at index 0, trim to `capacity`.
- `PTTLinkLog.entry(for:)`: rule text is `"\(rule.kind.rawValue) \(rule.pattern)"`.
- `PTTServiceProfiles`: trim whitespace; empty → nil / remove key. In tests use `UserDefaults(suiteName: "PTTTests-\(UUID())")!` and remove the suite afterwards (`removePersistentDomain(forName:)`).

## Done when
Tests cover all four branches:
(a) owned by a Chorus service → `.chorusService`/`.unchanged`, even when a rule would match;
(b) rule match wins over the service profile (e.g. youtube.com from a service whose profile is ONE → personal);
(c) no rule, service profile set → that profile; Drive/Docs link (no default rule) falls to the service profile and gets `authuser` from the profile email;
(d) no rule and no service profile → `.fallback`/`.unchanged`;
plus: redirect unwrapped before rule matching (a `google.com/url?q=https://youtube.com/...` link hits the youtube rule); profile name not in Chrome → `.missingProfile`; existing `authuser` kept; non-http scheme (`mailto:`) → fallback with original URL; empty service profile treated as nil; log keeps newest first and at most 20 (record 25, expect 20, newest first); log entry fields; service profile set/get/clear.
`swift build --package-path scripts/ptt-core-tests --target Chorus` passes.
