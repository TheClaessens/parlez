# 04: Automatic stop: 30 s of silence or 10 minutes

**What to build:** The Microphone reports a level reading into the Dictation core while recording, and the core exposes it with the recording state (the Island's meter will use it in ticket 05). A Dictation stops by itself after 30 s of continuous silence, or after 10 minutes regardless, and then transcribes and inserts exactly as a manual stop would. Spec user stories 15–17. Silence is judged from the level, not from Voz.

**Blocked by:** 01

**Status:** resolved

- [x] Core tests, driven by the fake Clock and fake levels: 30 s continuously below the silence threshold stops the Dictation and the Transcript is inserted.
- [x] Core tests: speech before 30 s resets the silence countdown.
- [x] Core tests: a Dictation reaching 10 minutes stops and inserts even if never silent.
- [x] The current level is part of the observable recording state.
- [ ] The silence threshold is a named constant; by hand it is tuned so normal speaking never counts as silence and a quiet room does.

## Comments

- 2026-10-30: Merged on `parlez/integration` (review fixes at 9b2f024). Automated checks pass (29 tests). "By hand" criteria await verification per the README hand-check checklist.
