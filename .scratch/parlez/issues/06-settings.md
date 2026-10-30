# 06: Settings window

**What to build:** A Settings window, opened from the menu, where I set the Dictation shortcut by pressing the combination I want (default ⌃⌥Space) and toggle Launch at login. Nothing else. Spec user stories 29–32.

**Blocked by:** 01

**Status:** resolved

- [ ] The menu has "Settings…", which opens the window and brings it to the front.
- [ ] The shortcut recorder changes the Dictation shortcut immediately and the choice survives a restart.
- [ ] Launch at login uses the system login-item service, and the toggle reflects the real registration state.

## Comments

- 2026-10-30: Merged on `parlez/integration` (review fixes at 9b2f024). Automated checks pass (29 tests). "By hand" criteria await verification per the README hand-check checklist.
