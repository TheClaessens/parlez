# 01: The Island works beside the notch

**What to build:** While a Dictation runs, the Island stays the height of the notch:
- **Recording:** a pulsing red dot and the elapsed time on the left of the notch, a live waveform driven by the level on the right.
- **Transcribing:** the time freezes, the dot becomes a thin spinner, and the waveform becomes a shimmer that runs across it, all in the same shape so nothing jumps.
- **Look:** the top corners curve into the screen edge like the notch's own, and the Island springs between sizes.
- **Menu bar:** the icon turns red while recording.
- **No notch:** the same content sits in a floating pill at the top centre.
- **Layout:** the panel's frame grows to the Island's largest size, including the message rows the later tickets use.

Existing signals keep working as they do today until tickets 02 and 03 replace them. Spec: `.scratch/island-redesign/spec.md`, user stories 1 to 12.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] The Dictation core exposes when the current Recording started, set while recording and cleared after, covered by Dictation tests.
- [ ] The Island layout frame matches the spec's sizes on a screen with a notch and without one, and the layout tests assert the new frames.
- [ ] While recording, the Island shows the dot, the running elapsed time and a level-driven waveform beside the notch at notch height.
- [ ] While transcribing, it keeps that shape and shows the spinner, the frozen time and the shimmer.
- [ ] The menu bar icon is red while recording and normal otherwise.
- [ ] On a screen without a notch the floating pill shows the same content.
- [ ] The README hand-check checklist's Island and level meter lines describe the new look.
- [ ] By hand: checked on the built-in display and on an external display as main.
