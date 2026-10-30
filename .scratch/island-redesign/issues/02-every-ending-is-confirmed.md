# 02: Every Dictation ending is confirmed

**What to build:** When a Dictation ends, a row drops below the notch for about 1.5 s, then the Island collapses:
- after a paste: "Pasted · N words", with a green check;
- after Esc: "Cancelled · nothing pasted";
- after an empty Transcript: "Nothing heard".

An accidental tap still shows nothing, and starting a new Dictation clears a confirmation at once. Spec: `.scratch/island-redesign/spec.md`, user stories 13 to 19.

**Blocked by:** 01

**Status:** ready-for-agent

- [x] The Dictation core raises `pasted` with the Transcript's word count after a successful insert, and not when the paste fails.
- [x] It raises `cancelled` when Esc cancels a recording, and nothing extra when Setup becomes incomplete mid-recording.
- [x] It raises `nothingHeard` for an empty Transcript, and nothing for a Recording under 0.3 s.
- [x] Each of these is covered by Dictation tests.
- [x] The Island shows each confirmation in a row below the notch (or in the floating pill) for about 1.5 s, then collapses.
- [x] Starting a new Dictation during a confirmation clears it immediately.
- [x] The README hand-check checklist covers the three confirmations.
