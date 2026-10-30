# 05: Island

**What to build:** The Island: a black pill that grows out of the notch to show the current Dictation. A live level meter while recording, a spinner while transcribing, a shake on the busy signal, a short red message on the error signal, and collapsing back into the notch when the Dictation ends. On a screen without a notch it floats at the top centre. It appears on the screen with the active menu bar, never takes focus, and only renders the Dictation core's state. Spec user stories 20–26.

**Blocked by:** 02, 04

**Status:** resolved

- [x] The Island is a borderless, non-activating panel above other windows that never steals focus or keyboard input from the app being dictated into.
- [x] It is sized and positioned from the screen's notch geometry when present, and at the top centre otherwise.
- [x] It renders recording (with the live level), transcribing, busy shake, error message and collapse, driven only by the core's state and signals.
- [ ] By hand: verified on the built-in display (notch) and on an external display as main (no notch).

## Comments

- 2026-10-30: Merged on `parlez/integration` (review fixes at 9b2f024). Automated checks pass (29 tests). "By hand" criteria await verification per the README hand-check checklist.
