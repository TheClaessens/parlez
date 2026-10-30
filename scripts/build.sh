#!/bin/bash
# Builds Parlez.app, signs it and installs it into /Applications.
#
#   scripts/build.sh                 build, sign, install
#   scripts/build.sh --build-only    build and sign into build/Parlez.app, don't install
#
# Signs with the first "Apple Development" identity in the keychain, so macOS keeps the
# microphone and Accessibility permissions across rebuilds, and ad-hoc otherwise.
# PARLEZ_SIGN_IDENTITY overrides the choice; "-" forces ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-install}"
app=build/Parlez.app

swift build -c release --product Parlez
bin="$(swift build -c release --show-bin-path)"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/Parlez" "$app/Contents/MacOS/Parlez"
# SwiftPM resource bundles (KeyboardShortcuts, Voz) are looked up in Contents/Resources.
for bundle in "$bin"/*.bundle; do cp -R "$bundle" "$app/Contents/Resources/"; done

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.thomasclaessens.parlez</string>
    <key>CFBundleName</key><string>Parlez</string>
    <key>CFBundleExecutable</key><string>Parlez</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>NSMicrophoneUsageDescription</key><string>Parlez listens while you dictate and turns your speech into text on this Mac.</string>
</dict>
</plist>
PLIST

identity="${PARLEZ_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')}"
identity="${identity:--}"
echo "Signing with: $([ "$identity" = - ] && echo ad-hoc || echo "$identity")"
codesign --force --sign "$identity" "$app"
codesign --verify --strict "$app"

if [ "$mode" = --build-only ]; then
    echo "Built $app"
    exit 0
fi

rm -rf /Applications/Parlez.app
ditto "$app" /Applications/Parlez.app
echo "Installed /Applications/Parlez.app"
