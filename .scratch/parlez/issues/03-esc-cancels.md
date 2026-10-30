# 03: Esc cancels a Dictation

**What to build:** While recording, pressing Esc cancels the Dictation: the Recording is thrown away, nothing is transcribed or inserted, and Parlez returns to idle. Outside a Dictation, Esc belongs to other apps again. Spec user stories 13–14.

**Blocked by:** 01

**Status:** resolved

- [x] Core tests: Esc while recording returns to idle with nothing transcribed or inserted.
- [x] Core tests: Esc while idle or transcribing changes nothing.
- [x] Esc is registered as a global hotkey only while recording and is unregistered as soon as the Dictation leaves recording, however it ends.
- [ ] By hand: Esc during a Dictation cancels it; Esc afterwards works normally in other apps.

## Comments

- 2026-10-30: Merged on `parlez/integration` (review fixes at 9b2f024). Automated checks pass (29 tests). "By hand" criteria await verification per the README hand-check checklist.
