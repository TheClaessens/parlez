# 01: Retouche on the Dictation shortcut

**What to build:** I turn on "Retouche (beta)" in Settings, dictate "The button should be red. Oh wait, actually the button should be green.", and "The button should be green." is inserted at the Caret. The Dictation shortcut now retouches every Dictation it stops, and so does an automatic stop. If the Retouched Transcript adds words I didn't say or line breaks, or the model fails, the plain Transcript is inserted instead. Where Retouche can't run (no Apple Intelligence, model not ready, macOS older than 26), the switch is greyed out with the reason and Dictations stay plain. Spec: `.scratch/retouche/spec.md`, user stories 1–4, 8, 11–23, 24–27, 29–31.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] The Dictation core takes a Retoucher adapter and a Retouche setting (off, on the Dictation shortcut, on its own shortcut), and retouches a stop, manual or automatic, when the setting is "on the Dictation shortcut" and the Retoucher is available. Esc never retouches.
- [x] The fallback rule from the spec (no new line breaks, ≥ 90 % of words out appeared in the Transcript) decides between the Retouched Transcript and the Transcript; a throwing Retoucher inserts the Transcript.
- [x] What was inserted is what "Copy last Transcript" holds and what `pasted(words:)` counts; an empty Retouched Transcript inserts nothing and raises `nothingHeard`.
- [x] A press while the Retoucher works raises busy; the Retoucher is warmed up when a Dictation starts with the setting on.
- [x] Each of the above is covered by Dictation tests with a fake Retoucher, using the prototype's email, "Paris" and translation outputs for the fallback.
- [x] A Foundation Models Retoucher (macOS 26+) uses the spec's instructions, greedy sampling and a fresh session per Retouche, and reports why it is unavailable; on older macOS an always-unavailable Retoucher reports "Needs macOS 26". The app still builds and runs on macOS 15.
- [x] Settings shows the "Retouche" switch with its "beta" badge and caption, below "Launch at login", as on the design canvas ("Retouche: Settings", states 1, 2 and 4) and in the spec's Settings decision; stored across launches; disabled with the reason and the "Until then…" line when the Retoucher is unavailable.
- [x] Until ticket 03, Retouche runs inside the transcribing state and the Island is unchanged.
- [x] The README hand-check checklist covers the switch, its greyed-out reasons, and real Dictations with self-corrections in English and Dutch.
