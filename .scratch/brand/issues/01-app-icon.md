# 01: The app icon

**What to build:** I run `scripts/build.sh` and Parlez.app has the Parlez mark as its icon in Finder: white with ink bars and an indigo caret in light mode, dark with light bars in dark mode, and following the tinted style. On macOS 15 it shows the same icon, flat. Spec: `.scratch/brand/spec.md`, user stories 1–3.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] `scripts/build.sh` compiles `brand/Parlez.icon` with actool using the command in the spec's App icon decision, with the deployment target taken from the same value as `LSMinimumSystemVersion`.
- [x] `Assets.car` and `Parlez.icns` end up in `Contents/Resources`; the generated Info.plist has `CFBundleIconFile` and `CFBundleIconName` set to `Parlez`.
- [x] `codesign --verify --strict` still passes, and `--build-only` and `--release` both include the icon.
- [x] The README's "Build from source" says Xcode is needed (for actool), and its hand-check checklist has the app icon items from the spec's Testing Decisions.

## Comments

Verified with `scripts/build.sh --build-only`: actool wrote `Assets.car` and `Parlez.icns`, the signature verifies, and Finder's icon for the built app renders the mark in light mode. The dark and tinted versions are in `Assets.car` but were only checked to be present; they are on the README hand-check. `--release` runs the same steps before zipping.
