# 03: Messages say what to do

**What to build:** An error drops a two-line row below the notch, with a red icon, the problem in white, and the fix underneath, and stays up for about 3 s.
- Pressing the Dictation shortcut before Setup is complete shows an amber "Finish Setup to dictate · Open Parlez from the menu bar".
- Pressing it while transcribing keeps the shake and adds "Still transcribing · one moment".

The core reports which error happened; the Island owns all the wording. Spec: `.scratch/island-redesign/spec.md`, user stories 20 to 27, and the fix-line copy in its Further Notes.

**Blocked by:** 01

**Status:** ready-for-agent

- [x] The Dictation core's error signal carries one of a fixed set of reasons (microphone didn't start, couldn't transcribe, paste failed) instead of free text, and the existing error tests assert the reasons.
- [x] The Island shows each error with its icon, title and fix line from the spec, for about 3 s.
- [x] Setup unfinished shows in amber with its own icon, and busy shows the shake plus "Still transcribing".
- [x] Errors, warnings and confirmations differ in icon as well as colour.
- [x] Two-line messages fit on a screen with a notch and in the floating pill.
- [x] The README hand-check checklist's Setup line says "Finish Setup to dictate".
