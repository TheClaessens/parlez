# 02: The menu bar icon

**What to build:** The menu bar shows the Parlez mark instead of the `waveform` symbol. It follows the menu bar's light or dark look, turns fully red while I'm recording, and is dimmed until Setup is finished. Spec: `.scratch/brand/spec.md`, user stories 4–7.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] `MenuBarIcon` draws the six rectangles from the spec's mark-shape decision into an 18 × 18 pt `NSImage(size:flipped:drawingHandler:)`, with no image file.
- [x] `recording`: the glyph is `systemRed` and not a template; `unavailable`: a template at 35 % opacity; every other state: an opaque template.
- [x] The image's accessibility description is "Parlez".
- [x] The README hand-check checklist has the menu bar items from the spec's Testing Decisions.

## Comments

Built with `swift build -c release`, no warnings. The app's `MenuBarIcon.mark` was rendered at 8× in all three states (template, red, dimmed) and matches `brand/parlez-mark.svg`; the six shapes are filled as one path so the dimmed caret has no darker joins. Not yet seen in a real menu bar: that is on the README hand-check.
