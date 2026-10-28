#!/usr/bin/env bash
# Build Chorus PTT in Release (ad-hoc signed) and install it to /Applications.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Chorus PTT.app"
BUNDLE_ID="com.ptt3199.Chorus"
BUILT_APP="build/ptt/Build/Products/Release/$APP_NAME"
INSTALLED_APP="/Applications/Chorus PTT.app"

for tool in xcodegen xcodebuild; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: $tool is not installed or not on PATH." >&2
        [ "$tool" = "xcodegen" ] && echo "Install it with: brew install xcodegen" >&2
        [ "$tool" = "xcodebuild" ] && echo "Install Xcode and run: xcode-select --switch /Applications/Xcode.app" >&2
        exit 1
    fi
done

echo "==> Generating the Xcode project"
xcodegen generate

echo "==> Building Chorus PTT (Release, ad-hoc signed)"
xcodebuild -project Chorus.xcodeproj -scheme Chorus -configuration Release \
    -destination 'platform=macOS' -derivedDataPath build/ptt \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build -quiet

if [ ! -d "$BUILT_APP" ]; then
    echo "error: build finished but '$BUILT_APP' was not found." >&2
    exit 1
fi

echo "==> Quitting Chorus PTT if it runs"
if pgrep -f "/Chorus PTT.app/Contents/MacOS/" >/dev/null; then
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" || true
    for _ in $(seq 1 10); do
        pgrep -f "/Chorus PTT.app/Contents/MacOS/" >/dev/null || break
        sleep 1
    done
    if pgrep -f "/Chorus PTT.app/Contents/MacOS/" >/dev/null; then
        pkill -f "/Chorus PTT.app/Contents/MacOS/" || true
    fi
fi

echo "==> Installing to $INSTALLED_APP"
rm -rf "/Applications/Chorus PTT.app"
ditto "$BUILT_APP" "$INSTALLED_APP"

echo "==> Opening Chorus PTT"
open "$INSTALLED_APP"
