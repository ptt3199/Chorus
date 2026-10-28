# Task 06 — Install and update scripts, README section

## Files you may edit
- `scripts/install-ptt.sh` (new, executable)
- `scripts/update-from-upstream.sh` (new, executable)
- `README.md` (only add a section at the very top, before the existing first line; do not change anything else)

## `scripts/install-ptt.sh`
bash, `set -euo pipefail`, runs from the repo root (`cd "$(dirname "$0")/.."`). Steps, each with a one-line `echo "==> ..."`:
1. `xcodegen generate`.
2. Build Release, signed ad-hoc, into a build folder inside the repo that git ignores (`build/ptt`, add nothing to .gitignore; use `-derivedDataPath build/ptt`):
   `xcodebuild -project Chorus.xcodeproj -scheme Chorus -configuration Release -destination 'platform=macOS' -derivedDataPath build/ptt CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build -quiet`.
   The product is `build/ptt/Build/Products/Release/Chorus PTT.app` (note the space; quote paths).
   NEVER run tests here (`test` with Release is forbidden in this repo).
3. Quit Chorus PTT if it runs: `osascript -e 'tell application id "com.ptt3199.Chorus" to quit'` when `pgrep -f "/Chorus PTT.app/Contents/MacOS/"` finds it; wait up to 10 s for it to exit, then `pkill` it.
4. Replace `/Applications/Chorus PTT.app` (`rm -rf` then `ditto`). Only ever touch that exact path.
5. `open "/Applications/Chorus PTT.app"`.
Fail with a clear message if `xcodegen` or `xcodebuild` is missing.

## `scripts/update-from-upstream.sh`
bash, `set -euo pipefail`, repo root. Refuse to run with uncommitted changes (`git diff --quiet && git diff --cached --quiet`).
1. `git fetch upstream` and `git fetch origin`.
2. `git checkout main && git merge --ff-only upstream/main`. If that fails, print why and stop.
3. `git push origin main`.
4. `git checkout ptt && git rebase main`. On conflict: print `git diff --name-only --diff-filter=U`, print "Resolve the conflicts (see Chorus/PTT/HOOKS.md: keep each PTT hook one line), then run: git rebase --continue && scripts/install-ptt.sh" and exit 1. Do not abort the rebase.
5. On success: `git push --force-with-lease origin ptt`, then run `scripts/install-ptt.sh`.

## README section (English, short, plain; this goes on GitHub)
Title `## Chorus PTT (this fork)`. Cover in a few bullets / short paragraphs:
- What differs from upstream: separate app "Chorus PTT" (bundle id `com.ptt3199.Chorus`, own data in `~/Library/Application Support/Chorus PTT`), no Sparkle updates, outside links open in the right Chrome profile (rules → service profile → Chorus default), ⌥-click and right-click profile menus, Settings › Links tab. Code lives in `Chorus/PTT/`; upstream files only get one-line hooks listed in `Chorus/PTT/HOOKS.md`.
- The rule file: `~/Library/Application Support/Chorus PTT/link-rules.json` (Debug builds: `Chorus PTT-debug`). Show a short JSON example with one rule of each kind (`domain`, `wildcard`, `regex`) using fields `kind`, `pattern`, `profile` (and say `id` is optional). Say: rules match top to bottom, first match wins; `profile` is the name Chrome shows for the profile; edits are picked up on the next link, or with Settings › Links › Reload.
- Install / update: `scripts/install-ptt.sh` and `scripts/update-from-upstream.sh`, what each does in one line. Requires Xcode and XcodeGen (`brew install xcodegen`).
- First launch if Gatekeeper blocks the ad-hoc signed app: right-click › Open, or `xattr -dr com.apple.quarantine "/Applications/Chorus PTT.app"`.
End the section with a horizontal rule `---` and a blank line, then leave the original README untouched.

## Done when
`bash -n` passes on both scripts, both are `chmod +x`, and `shellcheck` passes if installed. Do not run the scripts. Do not commit.
