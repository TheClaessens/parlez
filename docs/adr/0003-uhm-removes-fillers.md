# Uhm removes the fillers Voz lets through

Voz drops most fillers, but not near the seams of its 15 s windows or inside restarts (ADR 0001, corrected). We add an optional "Remove fillers" step that runs Desert Ant Labs' Uhm on the Recording and leaves out the words Voz transcribed inside the filler spans Uhm finds. This reopens the Uhm option ADR 0002 set aside: Uhm still can't apply self-corrections, which is why it didn't replace Retouche, but it is the right tool for fillers on their own. Like ADR 0002, this is a decision under test.

## Considered options

- **Uhm on the audio, dropping Voz's words inside its spans (chosen).** Ships in `desert-ant-core`, which we already depend on; runs on macOS 15 without Apple Intelligence; over 100× realtime, so it runs alongside Voz without a visible wait. The SDK's `Uhm.reconcileWords` already maps filler spans onto ASR words.
- **Retouche only.** Already drops fillers, but needs macOS 26 and Apple Intelligence, takes longer, and is opt-in for a different reason.
- **A word list ("uh", "um", "eh") removed from the text.** Simple, but can't tell a filler from a real word and misses fillers Voz spells differently.
- **Cutting fillers out of the audio before Voz.** Risks clipping real words and changes what Voz hears.

## Consequences

- A one-time 45 MB model download when the switch is first turned on. Setup is unchanged.
- Uhm is trained on English; Dutch works by acoustic transfer that hasn't been measured. The switch is off by default and labelled beta.
- Uhm has an "and"-as-filler class we can't filter without its unreliable type labels. With the `.precision` bias and dropping a word only when it lies fully inside a span, a lost real "and" should be rare; the hand-check watches for it.
- Uhm is under the same Desert Ant Labs Source-Available License as Voz.
