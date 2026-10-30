# 09: Setup window hides after granting a permission

**What to build:** After I grant a permission, the Setup window comes back to the front so I can see the next step, and pressing the Dictation shortcut while Setup is unfinished tells me why nothing happened instead of only shaking.

Found during the first hand check (2026-10-30): after granting the Microphone permission, the Setup window ended up behind other windows (the system prompt and System Settings take focus, and Parlez has no Dock icon to bring it back). It looked as if Setup had finished. The Dictation shortcut then only made the Island shake, because the Dictation core was still unavailable while Setup waited at the Accessibility step. Spec user stories 23 ("so that I understand why nothing happened"), 33 and 37.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] When a Setup step becomes satisfied and another step is still open, the Setup window is brought to the front.
- [x] Pressing the Dictation shortcut while Setup is unfinished brings the Setup window to the front.
- [x] In that case the Island shows a short "Finish Setup" message instead of only shaking (core test: a shortcut press while unavailable raises a signal that says Setup is unfinished; a press while transcribing still raises the plain busy shake).
- [ ] By hand: from a clean state, grant each permission and confirm the Setup window comes back to the front each time.


## Comments

- 2026-10-30: Implemented on `parlez/integration`. Automated checks pass (29 tests). The "By hand" criterion awaits verification per the README hand-check checklist (Setup from a clean state).
