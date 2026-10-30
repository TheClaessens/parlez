# 03: Retouche on the Island

**What to build:** When Retouche runs, the Island shows it in indigo: after I stop, "✦ Retouche" with an indigo shimmer replaces the transcribing look, and the confirmation reads "Pasted · 6 words · retouched". When Retouche falls back, it reads "Pasted as spoken · Retouche skipped" with a neutral check. A press during Retouche shakes the Island with "Still retouching". Stopping with the other shortcut shows straight away as the Retouche stage. The same works in the floating pill. Spec: `.scratch/retouche/spec.md`, user stories 32–38, the Island decision, and the "Retouche: Island states" artboard on the design canvas.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] The Dictation core has a retouching state between transcribing and idle while the Retoucher works; a press during it raises busy.
- [ ] The `pasted` signal says whether Retouche was not attempted, applied, or skipped.
- [ ] Both are covered by Dictation tests.
- [ ] The Island shows the Retouche stage (star and "Retouche" in indigo on the left, indigo shimmer on the right) beside the notch and in the floating pill.
- [ ] The Island shows "Pasted · N words · retouched" when applied, "Pasted as spoken · Retouche skipped" with a neutral outlined check when skipped, and "Still retouching · one moment" for busy during retouching.
- [ ] The README hand-check checklist covers the Retouche stage and both confirmations, on the built-in display and an external one.
