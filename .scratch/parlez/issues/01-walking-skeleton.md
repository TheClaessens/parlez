# 01: Walking skeleton: toggle Dictation into any app

**What to build:** Pressing ⌃⌥Space starts a Dictation; pressing it again stops it, Voz turns the Recording into a Transcript, and the Transcript is pasted at the Caret of the focused app with the clipboard restored afterwards. Parlez runs as a menu-bar app with no Dock icon and a menu holding only Quit. It is built, signed and installed into Applications by one script. This is the tracer bullet through every layer: Swift package (library + app + tests), build/install script, Dictation core, and the Microphone, Transcriber, Inserter and Clock adapters. See the spec's Implementation Decisions and Testing Decisions (`.scratch/parlez/spec.md`).

Not in this ticket: Setup (rely on the system's own permission prompts), the Island, Settings (the shortcut is fixed at ⌃⌥Space through `KeyboardShortcuts`' default), edge rules, Esc, automatic stop. Voz is loaded at launch, downloading the model first if it is missing.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] One Swift package (tools 6.2+, macOS 15+) with a library target for everything except the app entry point, an executable app target, and a test target using Swift's `Testing` framework; `swift build` and `swift test` pass.
- [x] The Dictation core takes events and exposes an observable state (at least idle, recording, transcribing); it makes no direct OS calls and talks only to the four adapters.
- [x] Core tests with fake adapters cover: the shortcut toggles idle → recording → transcribing → idle; the Transcript from the fake Transcriber reaches the fake Inserter; the last Transcript is kept.
- [x] The Inserter saves the clipboard, pastes with ⌘V, then restores the clipboard after a short delay.
- [ ] The build/install script assembles `Parlez.app` (agent app with no Dock icon, microphone usage description, bundle identifier `com.thomasclaessens.parlez`), signs it with the Apple Development identity when present and ad-hoc otherwise (overridable by an environment variable), and copies it into Applications.
- [ ] By hand: in TextEdit, ⌃⌥Space → speak → ⌃⌥Space pastes the Transcript at the Caret, and the clipboard still holds what was there before.

## Comments

- 2026-10-30: Merged on `parlez/integration` (review fixes at 9b2f024). Automated checks pass (29 tests). "By hand" criteria await verification per the README hand-check checklist.
