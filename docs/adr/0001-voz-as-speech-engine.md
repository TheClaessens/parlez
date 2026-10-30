# Voz as the speech engine

We transcribe with Desert Ant Labs' Voz (on-device, Core ML, Swift package `desert-ant-core`) rather than Apple's built-in speech APIs. On macOS 27, Apple's `SpeechTranscriber` has no Dutch, and `DictationTranscriber` does but needs one locale fixed up front, while we dictate in both English and Dutch. Voz covers both without switching.

## Consequences

- Voz pings `events.desertant.com` on every model load to count devices (no audio or text is sent). The Desert Ant Labs Source-Available License 1.0 forbids tampering with this, so we accept it. The README credits "Powered by Desert Ant Labs".
- Voz has no language detection or language setting. Speech outside its 25 languages produces confident nonsense. Mixing English and Dutch in one Dictation is out of scope unless Voz turns out to handle it.
- The model is a 467 MB download from Hugging Face, with ~20 s of Core ML preparation on first load.
