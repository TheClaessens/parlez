# 01: Remove fillers with Uhm

**What to build:** I turn on "Remove fillers (beta)" in Settings, its model downloads with progress shown, and from then on a Dictation like "So uh we ship on um Monday." inserts "So we ship on Monday." without any extra wait. Words that only touch a filler are kept, a Dictation where Uhm finds nothing is inserted exactly as Voz heard it, and if Uhm fails or isn't ready the plain Transcript is inserted. Spec: `.scratch/fillers/spec.md`, all user stories.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] The pure removing-fillers function (Voz text, Voz words, Uhm spans → Transcript) drops a word only when a filler span contains it, returns Voz's text unchanged when nothing is dropped, and joins surviving words otherwise; covered by the tests listed in the spec's Testing Decisions.
- [x] `VozTranscriber` runs Voz and Uhm concurrently on the Recording when the flag is on, with `.precision` bias and no type labels; it returns Voz's text when the flag is off or Uhm throws.
- [x] The app prepares Uhm's model (downloading it if missing) on one path, when the switch turns on and at launch with the switch on, and sets the Transcriber's flag once it is ready.
- [x] Settings shows the "Remove fillers" switch with its "beta" badge and caption, the download progress, and the failure message with "Try again", as in the spec's Settings decision; stored across launches.
- [x] ParlezKit depends on the `Uhm` product; minimum macOS stays 15.
- [x] ADR 0003 and the GLOSSARY "Filler" entry are in place (already written with this spec).
- [x] The README hand-check checklist covers the items in the spec's Testing Decisions.
