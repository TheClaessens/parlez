# 02: Dictation edge rules and Copy last Transcript

**What to build:** A Dictation behaves sensibly at its edges. An accidental tap (Recording under 0.3 s) does nothing. A silent Dictation (empty Transcript) inserts nothing. Pressing the Dictation shortcut while a Transcript is still being produced is ignored and raises a short-lived busy signal. A transcription failure raises a short-lived error signal and inserts nothing. The menu gains "Copy last Transcript", which puts the last Transcript on the clipboard. Spec user stories 10–12, 18 and 24 (signal only; the Island renders it in ticket 05).

**Blocked by:** 01

**Status:** resolved

- [x] Core tests: a Recording under 0.3 s is not transcribed and nothing is inserted.
- [x] Core tests: an empty Transcript inserts nothing.
- [x] Core tests: a shortcut press while transcribing is ignored, the state is unchanged, and a busy signal is raised.
- [x] Core tests: a transcription failure raises an error signal, inserts nothing, and returns to idle.
- [x] Menu "Copy last Transcript" copies the last Transcript; it is disabled when there is none.

## Comments

- 2026-10-30: Merged on `parlez/integration` (review fixes at 9b2f024). Automated checks pass (29 tests). "By hand" criteria await verification per the README hand-check checklist.
