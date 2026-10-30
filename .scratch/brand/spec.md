# Brand: the Parlez mark on the app icon, the menu bar and the README

Status: ready-for-agent

## Problem Statement

Parlez has no app icon: Finder, Spotlight and the permission lists in System Settings show the generic app icon. The menu bar shows the stock SF Symbol `waveform`, which many audio apps use. The README has no mark.

## Solution

Parlez gets its own mark: **sound to caret**, three bars of voice followed by the I-beam caret where the words land. The bars are ink and the caret is the brand accent **#7D7AFF**, the same indigo as Retouche's tint, so the app has one indigo. The name is set in SF Pro Display Semibold wherever it appears; there is no wordmark file.

The mark replaces the stock symbol in the menu bar, becomes the app icon (Liquid Glass on macOS 26 and later, a flat fallback on macOS 15), and sits above the README's title. The Island and the Setup window don't change; the Island's level bars already echo the mark.

Design canvas: https://claude.ai/artifact/LtvTDb6q5RATdQqFqs8828 (page "Final · A").

## User Stories

1. As a user, I want Parlez to have its own app icon, so that I recognise it in Finder, Spotlight, Login Items and the Privacy & Security lists.
2. As a user on macOS 26 or later, I want the icon to follow light, dark and tinted icon styles like other apps.
3. As a user on macOS 15, I want the same icon, flat, so that it doesn't look broken.
4. As a user, I want the menu bar icon to show the Parlez mark, so that I can tell it apart from other audio apps.
5. As a user, I want the menu bar icon to turn red while I'm recording, as it does today, so that I always know the microphone is on.
6. As a user who hasn't finished Setup, I want the menu bar icon dimmed, so that I can see Parlez isn't ready to dictate.
7. As a user, I want the menu bar icon to follow the menu bar's light or dark appearance in every other state.
8. As a reader of the README on GitHub, I want the mark above the title, readable in GitHub's light and dark themes.

## Implementation Decisions

- **The mark's shape** is six rounded rectangles on a 24-unit grid, centred on (12, 12), corner radius 1.25, with `brand/parlez-mark.svg` as the reference:
  - bars: (2.75, 8.75, 2.5 × 6.5), (6.75, 5.75, 2.5 × 12.5), (10.75, 7.75, 2.5 × 8.5)
  - caret: (14.75, 2.75, 6.5 × 2.5), (16.75, 2.75, 2.5 × 18.5), (14.75, 18.75, 6.5 × 2.5)
- **Colours:** ink #111114, accent #7D7AFF, light-on-dark bars #F5F5F7, dark icon background #1C1C1E.
- **App icon (ADR 0004):** `brand/Parlez.icon` (layers `bars.svg` and `caret.svg`, white background, dark-appearance background #1C1C1E and bars #F5F5F7) is compiled by `scripts/build.sh`:
  `xcrun actool brand/Parlez.icon --compile <dir> --app-icon Parlez --platform macosx --minimum-deployment-target 15.0 --standalone-icon-behavior all --output-partial-info-plist <dir>/partial.plist`
  `Assets.car` and `Parlez.icns` are copied into `Contents/Resources`, and the Info.plist the script writes gains `CFBundleIconFile` = `Parlez` and `CFBundleIconName` = `Parlez`. The minimum deployment target follows `LSMinimumSystemVersion`.
- **Menu bar icon:** `MenuBarIcon` draws the mark in code into an `NSImage(size:flipped:drawingHandler:)` of 18 × 18 pt, showing the 21-unit square from (1.5, 1.5) to (22.5, 22.5). There is no image file. The image's accessibility description stays "Parlez". By Dictation state:
  - `recording`: the whole glyph in `systemRed`, `isTemplate = false` (as today).
  - `unavailable`: drawn at 35 % opacity, template.
  - every other state: drawn opaque, template.
  It doesn't animate; the Island shows progress.
- **README:** above `# Parlez`, a `<picture>` with `brand/parlez-mark-dark.svg` for `prefers-color-scheme: dark` and `brand/parlez-mark.svg` otherwise, about 64 px tall, with alt text "Parlez". The title stays text.

## Testing Decisions

- No unit tests: the drawing code and the build step are thin, and nothing in ParlezKit changes.
- **By hand**, added to the README checklist:
  - After `scripts/build.sh`, Parlez.app shows the icon in Finder in light mode, dark mode and tinted icon style.
  - On macOS 15, if one is available, it shows the flat icon.
  - The menu bar icon is the mark on light and dark menu bars, red while recording, and dimmed before Setup is finished.
  - The README's mark shows in GitHub's light and dark themes.

## Out of Scope

- Any change to the Island or the Setup window.
- An animated menu bar icon.
- A wordmark file, a custom SF Symbol, or a website.
- Changing `retoucheTint` in code; it already has the accent's value.

## Further Notes

- The canvas also has the exploration rounds that led to this mark (pages "Round 1" and "Round 2").
- Building now needs Xcode installed for actool (ADR 0004); the README's "Build from source" should say so.
