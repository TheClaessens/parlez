# Remove fillers: leave out the "uh"s Voz lets through

Status: ready-for-agent

## Problem Statement

Voz drops most fillers by itself, but on longer Dictations some come through: near the seams between its 15 s windows, and inside restarts like "let's, uh, let's" (ADR 0001, corrected). Retouche drops them when it runs, but it is opt-in, needs macOS 26 and Apple Intelligence, and takes longer. A plain Dictation has no way to leave fillers out.

## Solution

**Remove fillers (beta)** is an optional switch in Settings. When it is on, Parlez runs Desert Ant Labs' Uhm on the Recording alongside Voz. Uhm finds the time spans of "uh", "um" and "hmm" in the audio, and the words Voz transcribed inside those spans are left out of the Transcript. It runs on the Mac on macOS 15 and later, and adds no visible wait: Uhm runs at over 100× realtime, in parallel with Voz (ADR 0003).

It is off by default. Turning it on downloads Uhm's model once (about 45 MB), with progress shown in Settings. Until the model is ready, and whenever Uhm fails, the Transcript is Voz's text unchanged, so a Dictation is never lost.

Removing fillers happens before Retouche, so a Dictation can use both: Retouche then works on a Transcript with the fillers already gone.

## User Stories

1. As a user, I want Remove fillers off by default, so that Parlez keeps inserting Voz's Transcript as it is until I choose otherwise.
2. As a user, I want a "Remove fillers (beta)" switch in Settings, so that I can leave out the fillers Voz lets through.
3. As a user, I want the "beta" label, so that I know this is still being tried out, especially in Dutch.
4. As a user, I want the switch remembered across launches, so that I set it once.
5. As a user turning it on for the first time, I want the model download to start straight away with its progress shown, so that I know when it works.
6. As a user whose download failed, I want a message and a way to retry, so that I'm not stuck.
7. As a user, I want Dictations to stay as they are until the model is ready, so that turning the switch on never blocks a Dictation.
8. As a user with Remove fillers on, I want "uh", "um" and "hmm" that Voz transcribed left out, so that the text reads cleanly.
9. As a user, I want words that only touch a filler kept, so that a real word next to an "uh" is never cut.
10. As a user, I want my words exactly as Voz heard them when Uhm finds no fillers, so that nothing else about the Transcript changes.
11. As a user, I want Voz's Transcript inserted when Uhm fails, so that I never lose a Dictation.
12. As a user, I want nothing inserted when everything I said was a filler, so that an empty Dictation stays silent as before.
13. As a user, I want the "Pasted" count and "Copy last Transcript" to reflect the Transcript without fillers, so that they match what was inserted.
14. As a user with Retouche on as well, I want fillers removed before Retouche runs, so that both work together.
15. As a user, I want Remove fillers to work on macOS 15, so that it doesn't need Apple Intelligence.
16. As a user, I want Setup unchanged, so that Remove fillers never blocks my first Dictation.
17. As a user, I want no extra wait on the Island, so that the Dictation feels as fast as before.

## Implementation Decisions

- **Where it runs:** in the Transcriber adapter. The Dictation core keeps receiving a Transcript as text, and its rules (empty Transcript → `nothingHeard`, Retouche, word count, last Transcript) apply unchanged. The Island doesn't change.
- **`VozTranscriber`** gets a "remove fillers" flag the app sets once Uhm's model is ready and the switch is on. When the flag is on, it runs `voz.transcribe(samples:sampleRate:)` and `uhm.analyze(samples:sampleRate:options:)` on the same Recording concurrently. It then removes fillers from Voz's words. When the flag is off or Uhm throws, it returns Voz's `.text` as today.
- **Removing fillers** is one pure function in ParlezKit, taking Voz's text, Voz's words (with start and end times) and Uhm's filler spans, and returning the Transcript:
  - A word is dropped only when some filler span contains it (`span.start <= word.start && word.end <= span.end`), including a word without duration. This is the only drop case of `Uhm.reconcileWords`; we don't call it because its other cases only trim timings we don't use, and it also drops words without duration.
  - When no word is dropped, return Voz's `.text` unchanged.
  - Otherwise, join the surviving words with single spaces. (Voz's words carry their punctuation, so this matches `.text` apart from the dropped words.)
- **Uhm options:** `bias: .precision` (0.75, the SDK's recommendation for automatic cuts), `includeTypes: false` (the type labels are unreliable and the labeler costs time). Uhm's "and"-as-filler class can't be told apart without types; the drop-only-when-fully-inside rule plus precision is the guard, and the hand-check watches for lost "and"s.
- **The model:** one `Uhm` instance in `VozTranscriber`, which offers `prepareFillerModel(progress:)`: download the model (`download(progress:)`) if it is missing, then load it by analyzing a short silence (Uhm loads lazily on the first `analyze`). The app prepares it on one path, when the switch turns on and at launch with the switch on, downloading it if missing since the user chose it. Its progress, ready and failed state lives in the app next to Setup's, and the flag is set only once it is ready.
- **Settings** (below "Launch at login", above the Retouche divider): a divider, then the "Remove fillers" switch with the same small "beta" badge as Retouche and the caption "Leaves out “uh”, “um” and “hmm” that Voz lets through, by listening for them in your Recording. Runs on this Mac. One-time 45 MB download." While downloading (not while loading a model already on disk): a progress bar. On a failed download: "The download failed. Check your connection."; on a failed load of a model on disk: "Couldn't load the filler model."; either with a "Try again" button. Stored in user defaults.
- **Package:** add the `Uhm` product of `desert-ant-core` (already a dependency) to ParlezKit.
- **ADR 0003** records the choice; it reopens the Uhm option ADR 0002 set aside, for filler removal only.

## Testing Decisions

- **Removing fillers** (the pure function), with constructed Voz words and Uhm spans:
  - A word fully inside a filler span is dropped: "So uh we ship Monday." → "So we ship Monday."
  - A word only partly overlapping a filler span is kept.
  - No filler spans, or spans covering no word: Voz's text is returned unchanged.
  - Every word inside filler spans: the result is empty.
  - Punctuation attached to kept words stays ("Monday." keeps its full stop).
  - A word without duration is dropped inside a filler span and kept outside one.
- **By hand**, added to the README checklist: the switch and its download (progress, failure and retry), Dictations with fillers in English, Dutch and mixed with the switch on and off, a sentence with a real "and" next to a pause, and Remove fillers together with Retouche.
- The `VozTranscriber` wiring and the `Uhm` model management are thin wrappers checked by hand.

## Out of Scope

- Cutting fillers out of the audio before Voz transcribes it.
- Removing fillers Voz didn't transcribe as words (they aren't in the Transcript anyway).
- A setting for Uhm's bias, or per-language behaviour.
- Downloading Uhm's model during Setup.
- Any Island change.

## Further Notes

- This reverses the Retouche spec's out-of-scope line on Uhm (`.scratch/retouche/spec.md`) for filler removal; ADR 0003 records why. Uhm still doesn't handle self-corrections; that remains Retouche's job.
- Uhm is trained on English and reaches Dutch by acoustic transfer that Desert Ant Labs hasn't measured. That's why the switch is beta and off by default.
- Like Voz, Uhm is under the Desert Ant Labs Source-Available License; the README's credit covers it.
