# Voz as the speech engine

We transcribe with Desert Ant Labs' Voz (on-device, Core ML, Swift package `desert-ant-core`) rather than Apple's built-in speech APIs. On macOS 27, Apple's `SpeechTranscriber` has no Dutch, and `DictationTranscriber` does but needs one locale fixed up front, while we dictate in both English and Dutch. Voz covers both without switching.

## Consequences

- Voz pings `events.desertant.com` on every model load to count devices (no audio or text is sent). The Desert Ant Labs Source-Available License 1.0 forbids tampering with this, so we accept it. The README credits "Powered by Desert Ant Labs".
- Voz has no language detection or language setting. Speech outside its 25 languages produces confident nonsense. Mixing English and Dutch in one Dictation is out of scope unless Voz turns out to handle it.
- The model is a 467 MB download from Hugging Face, with ~20 s of Core ML preparation on first load.
- The spike (branch `prototype/voz-spike`, see its `VERDICT.md`) confirmed this choice: ~50× realtime on an M3 Pro, near-perfect English and Dutch. Voz drops filler words by itself, so no separate filler-removal model is needed. (Corrected 2026-10-30: this holds inside one 15 s window. Voz transcribes longer audio in overlapping 15 s windows, and fillers near a window seam, or inside a restart like "let's, uh, let's", come through. Shifting one recording against the seam moved the fillers with it. Accepted as is; Retouche drops them when it runs, see 0002.) Mixed English/Dutch in one sentence is unreliable, and its `vocabulary` bias barely helped.
