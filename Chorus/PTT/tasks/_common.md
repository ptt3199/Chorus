## Rules for every task (read first)
- Repo: this checkout of Chorus PTT (fork of nicojan/Chorus), branch `ptt`. Swift 6, strict concurrency, macOS 14 deployment target.
- Edit ONLY the files listed under "Files you may edit". Do not touch any other file, do not run `git commit`, `git checkout`, `git stash` or `xcodegen`.
- Code in `Chorus/PTT/Core/` is pure logic: `import Foundation` only (no SwiftUI, AppKit, WebKit, no `AppLogger` or other app types). It must compile on its own.
- Keep every declared signature exactly as written (names, parameter labels, types). Replace each `fatalError("TODO")` body with a real implementation. You may add `private` helpers in the same file.
- Tests: XCTest (`import XCTest`, `@testable import Chorus`, `final class ...: XCTestCase`, methods `func test...()`). Do not use Swift Testing. No network, no reading real files from the home folder: use temp directories (`FileManager.default.temporaryDirectory`) and in-memory `Data`.
- Code comments and identifiers in English. Match the existing style: small, clear doc comments, no clever tricks.
- Check: `swift build --package-path scripts/ptt-core-tests --target Chorus` must succeed with no errors and no warnings in PTT files. (XCTest is not available locally yet; the lead runs the tests.)
- When finished, print a short summary of what you did.
