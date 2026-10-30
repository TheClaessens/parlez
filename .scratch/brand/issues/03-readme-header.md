# 03: The mark in the README

**What to build:** Opening the repo on GitHub, I see the Parlez mark above the "Parlez" title, readable in both GitHub's light and dark themes. Spec: `.scratch/brand/spec.md`, user story 8.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] Above `# Parlez`, a `<picture>` uses `brand/parlez-mark-dark.svg` for `prefers-color-scheme: dark` and `brand/parlez-mark.svg` otherwise, about 64 px tall, alt text "Parlez".
- [x] The title stays a text heading.

## Comments

Both SVG paths resolve from the repo root. How GitHub draws it in its light and dark themes is checked after a push.
