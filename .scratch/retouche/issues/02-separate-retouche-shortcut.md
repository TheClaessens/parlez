# 02: A separate Retouche shortcut

**What to build:** With Retouche on, I check "Use a separate shortcut for Retouche". The Dictation shortcut (⌃⌥Space) goes back to inserting the plain Transcript, and a Retouche shortcut (⌃⌥Z by default, changeable) retouches. Either shortcut starts a Dictation; the one I stop with decides whether it is retouched, so I can decide after I've spoken. An automatic stop isn't retouched in this setting. If Retouche becomes unavailable, the Retouche shortcut keeps working as a plain Dictation shortcut. Spec: `.scratch/retouche/spec.md`, user stories 5–7, 9–10, 12, 28.

**Blocked by:** 01

**Status:** resolved

- [x] A shortcut press tells the Dictation core which shortcut it was; with the setting "on its own shortcut", only a stop by the Retouche shortcut retouches, whichever shortcut started the Dictation, and an automatic stop doesn't.
- [x] With the setting off, or the Retoucher unavailable, the Retouche shortcut behaves exactly like the Dictation shortcut.
- [x] Each of the above is covered by Dictation tests.
- [x] A Retouche shortcut, ⌃⌥Z by default, is registered only while "Use a separate shortcut for Retouche" is checked, and stays registered when Retouche becomes unavailable.
- [x] Settings shows the checkbox under the Retouche switch once it is on, and the "Retouche shortcut:" recorder with its caption once it is checked, as on the design canvas ("Retouche: Settings", states 2 and 3); both are stored across launches.
- [x] The README hand-check checklist covers the Retouche shortcut in real apps, including starting with one shortcut and stopping with the other.
