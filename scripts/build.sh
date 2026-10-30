#!/bin/bash
# Builds Parlez.app, signs it and installs it into /Applications.
#
#   scripts/build.sh                 build, sign, install
#   scripts/build.sh --build-only    build and sign into build/Parlez.app, don't install
#   scripts/build.sh --release       build and sign, then zip into build/Parlez-<version>.zip
#
# Signs with the first "Apple Development" identity in the keychain, so macOS keeps the
# microphone and Accessibility permissions across rebuilds, and ad-hoc otherwise.
# PARLEZ_SIGN_IDENTITY overrides the choice; "-" forces ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-install}"
app=build/Parlez.app
version=0.2.0  # bump before each release
min_macos=15.0

swift build -c release --product Parlez
bin="$(swift build -c release --show-bin-path)"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/Parlez" "$app/Contents/MacOS/Parlez"
# SwiftPM resource bundles (KeyboardShortcuts, Voz) are looked up in Contents/Resources.
for bundle in "$bin"/*.bundle; do cp -R "$bundle" "$app/Contents/Resources/"; done
# The app icon: Assets.car for macOS 26 and later, Parlez.icns for macOS 15 (ADR 0004). actool needs Xcode.
xcrun actool brand/Parlez.icon --compile "$app/Contents/Resources" --app-icon Parlez --platform macosx \
    --minimum-deployment-target "$min_macos" --standalone-icon-behavior all \
    --output-partial-info-plist build/icon-info.plist --output-format human-readable-text

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.thomasclaessens.parlez</string>
    <key>CFBundleName</key><string>Parlez</string>
    <key>CFBundleExecutable</key><string>Parlez</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$version</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleIconFile</key><string>Parlez</string>
    <key>CFBundleIconName</key><string>Parlez</string>
    <key>LSMinimumSystemVersion</key><string>$min_macos</string>
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

if [ "$mode" = --release ]; then
    zip="build/Parlez-$version.zip"
    rm -f "$zip"
    ditto -c -k --keepParent "$app" "$zip"  # ditto keeps the signature intact, zip(1) can break it
    echo "Built $zip"
    exit 0
fi

rm -rf /Applications/Parlez.app
ditto "$app" /Applications/Parlez.app
echo "Installed /Applications/Parlez.app"
