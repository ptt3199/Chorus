# Chorus PTT — report

## What was done

| Commit | What | Who |
|---|---|---|
| `chore: split Chorus PTT into its own app` | Bundle ids `com.ptt3199.Chorus` / `.debug` / `com.ptt3199.ChorusTests`, product "Chorus PTT" (module stays `Chorus`), Release signs ad-hoc, store and TipKit in `Application Support/Chorus PTT` (`Chorus PTT-debug` for Debug), `StoreRelocation` never adopts the original Chorus store, Sparkle package and Info.plist keys removed, `pages.yml` deleted, CI runs on `ptt`. | lead |
| `fix(ptt): point the test host at Chorus PTT.app` | XcodeGen named the test host after the target, not the product. | lead |
| `feat(ptt): contract API ...` | Core types with TODO bodies, SwiftPM harness (`scripts/ptt-core-tests`), task briefs, plan. | lead |
| `feat(ptt): link rules ...` | Domain / wildcard / regex rules, ordered rule set, JSON file format, defaults. | Copilot (task 01) |
| `feat(ptt): unwrap Google redirects ...` | `google.com/url?q=` / `url=` unwrapping (nested), `authuser` on docs/drive/meet/sheets/slides. | Copilot (task 02) |
| `feat(ptt): read Chrome profiles ...` | `Local State` parsing, lookup by display name, launch arguments. | Copilot (task 03) |
| `feat(ptt): decide which Chrome profile opens a link` | Resolver (a→d), link log (20, in memory), per-service profile in UserDefaults. | Copilot (task 04) |
| `feat(ptt): open outside links in the right Chrome profile` | `PTTLinkService`, hooks, ⌥-click menu, right-click menu (`PTTWebView`), `HOOKS.md`. | lead |
| `feat(ptt): Links settings tab and per-service Chrome profile` | Settings › Links tab, Edit Service picker. | Copilot (task 05) |
| `fix(ptt): keep runtime code within what Xcode 16.2 accepts` | Review fixes. | lead |
| `fix(ptt): route links inside a service popup ...` | Google Chat opens Docs links in a named popup and reuses it; a new hook sends those navigations to Chrome. | lead |
| `fix(ptt): keep the right-click link script ...` | Chorus clears all user scripts when it applies a dark theme, which removed the script behind "Open in Chrome Profile"; `PTTWebView` now restores it on load, reload and right-click. | lead |
| `build(ptt): install script builds arm64 only` (+ generic destination) | Local installs skip the x86_64 slice. | lead |
| `docs(ptt): install and upstream-update scripts, README section` | `scripts/install-ptt.sh`, `scripts/update-from-upstream.sh`, README section. | Copilot (task 06), README example fixed by lead |

Every Copilot task passed review on the first try; agy was not needed.

## Tests and CI

- 58 unit tests in `ChorusTests/PTT/` (XCTest: rules 18, URL rewriting 14, resolver 15, Chrome profiles 10, smoke 1): every match kind, rule order, no match, nested redirects, existing `authuser`, missing profile, broken or missing Local State, all four decision branches, log capacity.
- CI (`.github/workflows/test.yml`, macOS 14 + macOS 15, Debug) on `ptt`: green. 517 tests, 0 failures, all five PTT suites ran on both OSes.
- Review: `git grep "// PTT:"` outside `Chorus/PTT` gives 17 lines, all listed in `HOOKS.md`. No `updates.nicojan.com` and no Sparkle left in the app or project.

## Decisions worth knowing

- **Rule (a), "a Chorus service owns the domain"**, applies where Chorus already switches to a service: clicked links and `window.open`. ⌘-click, the toolbar's "Open in Browser" and the rail's "Open in Browser" are explicit requests for a browser, so they skip (a) and go straight to rules and the service profile. Otherwise "Open in Browser" on Chat ONE would never reach the ONE profile, because Chat QUAVEO also covers `chat.google.com`.
- A service set to open outside links in a **Chorus window** keeps doing that; rules apply to links that would go to the browser.
- `window.open` goes to Chrome only for an unsized window to another site that is not a sign-in page, and only when a profile that exists applies. Sign-in popups keep working.
- The Edit Service picker saves at once (Cancel does not undo it). It is stored in UserDefaults, not in the SwiftData model.
- Right-click: WebKit does not say which link a menu is for, so a small script in an isolated world reports the link under the pointer. Chorus PTT replaces WebKit's "Copy Link" with one that strips Google's redirect.
- The rule file is re-read whenever it changed on disk, so hand edits work on the next link.

## What you need to do

1. **Chrome profile names.** Rules use the name Chrome shows. Your profiles are currently named **"Thành"**, **"ONE"** and **"quaveo.ai"**, while the default rules say `personal` and `ONE`. Either rename the Chrome profiles to `personal` and `QUAVEO` (Chrome › profile menu › Customize profile), or change the names in Settings › Links (or in the rule file). Until then, youtube.com and facebook.com rules fall back to the default browser and say "Profile not found" in the log.
2. **Open the app.** It is ad-hoc signed. If Gatekeeper blocks it: right-click `/Applications/Chorus PTT.app` › Open, or run
   `xattr -dr com.apple.quarantine "/Applications/Chorus PTT.app"`.
3. **Add the two Google Chats** (Chat ONE, Chat QUAVEO) and sign in to each. Chorus PTT has its own data, so nothing from the original Chorus carries over. Give them separate sign-ins (Edit Service › sign-in store) so the two accounts do not share cookies.
4. **Pick a profile per Chat:** Edit Service › Chrome profile › ONE / QUAVEO.
5. Check Settings › Links: try a link in "Test a link", and watch "Recent links" after clicking a few.

Rule file: `~/Library/Application Support/Chorus PTT/link-rules.json`.
Update later with `scripts/update-from-upstream.sh`.

## Vietnamese input

Typing Vietnamese in Google Chat went wrong with the VietTelex input method.
VietTelex sets its typing mode per bundle id; `com.ptt3199.Chorus` is not in
its table, so it used Tap (backspace-retype), which WebKit swallows. Fixed on
this Mac by pinning Chorus PTT to In-place (Gõ trực tiếp) in VietTelex
Settings › Ứng dụng; steps are in the README. No change to the app.

## Not done / caveats

- The local install came from the CI build; see "Install status" below.
- The right-click menu and the Chrome launch were checked in the app; the ⌥-click menu was checked by compiling and unit tests only.

## Install status

- First install: from the CI Release build, while Xcode was still downloading.
- Current install: built locally with `scripts/install-ptt.sh` (Xcode 27.1,
  arm64 only) from `746ad39`. Checked by hand: "Open in Chrome Profile" from a
  link's right-click menu in Google Chat.
- Local `xcodebuild test` (Debug): 520 tests, 0 failures, all six PTT suites.
