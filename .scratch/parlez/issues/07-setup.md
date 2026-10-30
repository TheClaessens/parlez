# 07: Setup

**What to build:** On first launch a Setup window walks through three steps: Microphone permission; Accessibility permission (explained, with a button opening the right System Settings pane, and detecting the grant without a restart); and downloading and preparing the speech model with a progress bar. This replaces ticket 01's model download at launch. Until Setup is complete the Dictation core is unavailable: the Dictation shortcut is ignored with the busy signal. If the model goes missing or a permission is revoked later, Setup reopens at that step. Spec user stories 33–40.

**Blocked by:** 02

**Status:** ready-for-agent

- [x] Core tests: before Setup is complete, a shortcut press starts nothing and raises the busy signal; after completion, it starts a Dictation.
- [ ] The Setup window shows the three steps with their status, and moves on as each one is granted or finished.
- [ ] The model step shows download progress, then loads the model once so the first Dictation is fast.
- [ ] At launch, if any step is not satisfied, Setup opens at the first unsatisfied step; otherwise it does not appear.
- [ ] By hand: verified from a clean state (permissions reset, model cache removed).
