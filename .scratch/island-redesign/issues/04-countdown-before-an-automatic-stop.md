# 04: Countdown before an automatic stop

**What to build:** While I'm silent during a Dictation, the waveform drops to still dots. In the last 10 s before the silence stop, a row drops below the notch with an amber countdown ring and "No speech · stopping in N s". It disappears the moment I speak again. The same countdown, reading "Time limit · stopping in N s", appears in the last 10 s before the 10-minute stop. The automatic stop then transcribes and pastes as before. Spec: `.scratch/island-redesign/spec.md`, user stories 28 to 32.

**Blocked by:** 01

**Status:** ready-for-agent

- [x] The Dictation core exposes the earliest pending automatic stop while recording, as an instant plus a reason (silence or length limit), and nil otherwise.
- [x] Dictation tests cover each part of that value's behaviour:
  - it reports the length limit while there is sound;
  - it switches to the silence stop when silence starts, and back when sound returns;
  - it is nil outside recording;
  - the automatic stop happens at the instant it reported.
- [x] The Island shows the countdown ring and the right label when the automatic stop is 10 s away or less, and hides it as soon as the stop moves further away.
- [x] The waveform shows still dots while the level is below the silence threshold.
- [x] The README hand-check checklist's silence line covers the countdown.
