# Task 03 — Chrome profiles from Local State

## Goal
Implement `Chorus/PTT/Core/PTTChromeProfiles.swift` as its doc comments describe, and write unit tests.

## Files you may edit
- `Chorus/PTT/Core/PTTChromeProfiles.swift`
- `ChorusTests/PTT/PTTChromeProfilesTests.swift` (new)

## API
Foundation `JSONSerialization` (Local State has many unrelated keys; do not model the whole file). Define a small `enum ParseError: Error` inside `PTTChromeProfiles` if needed.
Local State shape (excerpt):
```json
{ "profile": { "info_cache": {
    "Default":   { "name": "personal", "user_name": "me@gmail.com" },
    "Profile 1": { "name": "ONE",      "user_name": "me@one.com" },
    "Profile 3": { "name": "QUAVEO",   "user_name": "" } } } }
```
Entries missing `name` are skipped. `user_name` missing or empty → `email == nil`.

## Done when
Tests cover: parsing the sample (3 profiles, sorted by name, emails, empty email → nil), malformed JSON throws, JSON without `profile.info_cache` throws, `load(from:)` with a missing file returns `[]`, `load(from:)` with a corrupt file returns `[]`, `load(from:)` with a valid temp file, `find` by name case-insensitive and trimmed, `find` by directory, `find` unknown → nil, `launchArguments`.
`swift build --package-path scripts/ptt-core-tests --target Chorus` passes.
