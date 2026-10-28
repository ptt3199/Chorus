# Task 02 — Redirect unwrapping and authuser

## Goal
Implement `Chorus/PTT/Core/PTTURLRewriting.swift` as its doc comments describe, and write unit tests.

## Files you may edit
- `Chorus/PTT/Core/PTTURLRewriting.swift`
- `ChorusTests/PTT/PTTURLRewritingTests.swift` (new)

## API
Foundation `URLComponents` / `URLQueryItem`. `URLComponents.queryItems` already percent-decodes values.
- `unwrapRedirect`: host must be `google.com` or `www.google.com` (case-insensitive), path exactly `/url`. Prefer `q`, then `url`. The target must parse as a URL with scheme http or https; otherwise return the input unchanged. Loop up to 5 times.
- `addingAuthUser`: host compared lowercased. Append `URLQueryItem(name: "authuser", value: email)` to existing items (keep order). Keep fragment. Note `+` and `@` in emails: make sure the email survives (set `percentEncodedQueryItems` carefully or encode `+` as `%2B` so it is not read as a space). Test `a+b@x.com`.

## Done when
Tests cover: plain URL unchanged, `q=` redirect, `url=` redirect, `www.google.com` and `google.com`, nested redirect (redirect whose target is another redirect), redirect with a non-http target (`javascript:`) unchanged, google.com path other than `/url` unchanged, percent-encoded target with its own query string preserved; authuser added on docs/drive/meet/sheets/slides, not added on mail.google.com or other hosts, not added when already present (with any value), nil/empty email unchanged, existing query and fragment kept, email with `+`.
`swift build --package-path scripts/ptt-core-tests --target Chorus` passes.
