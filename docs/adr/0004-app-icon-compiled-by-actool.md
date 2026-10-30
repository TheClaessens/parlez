# The app icon is compiled from an Icon Composer file by actool in build.sh

Parlez is a SwiftPM package with no Xcode project and no asset catalog; `scripts/build.sh` assembles `Parlez.app` by hand. The app icon's source is `brand/Parlez.icon`, an Icon Composer file, and `build.sh` compiles it with `xcrun actool`. One run writes `Assets.car` with the Liquid Glass light, dark and tinted renditions for macOS 26 and later, and a flat `Parlez.icns` that macOS 15 uses, so one source covers the whole deployment range.

## Considered options

- **Icon Composer file compiled by actool in build.sh (chosen).** Native icon on macOS 26+, fallback on 15, no change to how the app is built besides one command and two Info.plist keys.
- **A 1024 px PNG turned into `.icns` with iconutil.** Simplest, but macOS 26 restyles icons that aren't Icon Composer icons, can shrink them onto a grey squircle, and gives them no dark or tinted appearance.
- **An Xcode project.** Handles icons without extra plumbing, but replaces the whole SwiftPM build for the sake of one asset.

## Consequences

- Building needs Xcode installed (actool ships with it), not only the command-line tools.
- `brand/Parlez.icon` is edited in Icon Composer (inside Xcode); its `icon.json` can also be edited by hand.
