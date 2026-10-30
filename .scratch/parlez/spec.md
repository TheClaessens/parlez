# Parlez: on-device dictation into any app

Status: resolved

## Problem Statement

I think out loud and fidget while I do, but turning that into text means stopping to type. Apple's built-in dictation doesn't fit: the engine I want (Voz) isn't what macOS uses, and I switch between English and Dutch. I want to press a key, talk for as long as I need, press it again, and have my words appear wherever I was typing, in any app, without sending audio off my Mac.

## Solution

Parlez is a menu-bar app for macOS. Pressing the **Dictation shortcut** starts a **Dictation**; pressing it again stops it. While I talk, an **Island** grows out of the notch to show that it's listening, with a live level meter. When I stop, Voz turns the **Recording** into a **Transcript** on-device in a fraction of a second, and Parlez pastes it at the **Caret** of whatever app has focus, then puts my clipboard back. If I walk away, it stops by itself after 30 s of silence or 10 minutes. Esc cancels. The first time it opens, a **Setup** window gets the microphone and accessibility permissions and downloads the speech model, so the first Dictation is instant. Friends can download a zip from GitHub Releases and use it without building anything.

## User Stories

### Dictation

1. As a user, I want to press the Dictation shortcut once to start a Dictation, so that I can talk hands-free while I think and fidget.
2. As a user, I want to press the Dictation shortcut again to stop the Dictation, so that I decide when I'm done.
3. As a user, I want the Transcript inserted at the Caret of the app that has focus when it's ready, so that the text lands where I'm working.
4. As a user, I want the Transcript inserted in one go after I stop, so that text never shifts around in someone else's field while I'm still talking.
5. As a user, I want the Transcript inserted exactly as Voz produced it, punctuation and capitals included, so that nothing rewrites my words.
6. As a user, I want filler words like "uhm" and "eh" left out of the Transcript, so that the text reads cleanly. (Voz already does this.)
7. As a user, I want to dictate in English or in Dutch without choosing a language, so that I can just talk.
8. As a user, I want my clipboard restored after the Transcript is pasted, so that dictating never destroys what I had copied.
9. As a user, I want the Transcript inserted wherever focus is when it's ready, even if I switched apps during the Dictation, so that the behaviour is predictable.
10. As a user, I want a "Copy last Transcript" item in the menu, so that I can recover the text when the paste went nowhere (no text field had focus).
11. As a user, I want a Recording shorter than 0.3 s to be thrown away silently, so that an accidental double-tap does nothing.
12. As a user, I want nothing inserted when the Transcript is empty, so that a silent Dictation leaves no trace.
13. As a user, I want to press Esc during a Recording to cancel the Dictation, so that I can abandon a false start without anything being inserted.
14. As a user, I want Esc to be left alone outside a Dictation, so that Parlez doesn't steal it from other apps.
15. As a user, I want a Dictation to stop by itself after 30 s of continuous silence, so that a forgotten Dictation doesn't keep the microphone open, while normal thinking pauses don't cut me off.
16. As a user, I want a Dictation to stop by itself after 10 minutes, so that a noisy room that never goes silent can't keep it recording forever.
17. As a user, I want an automatic stop to transcribe and insert what was said, just like a manual stop, so that I don't lose anything.
18. As a user, I want a press of the Dictation shortcut while a Transcript is still being produced to be ignored, so that Dictations never overlap or queue up.
19. As a user, I want the Transcript produced fast enough that it feels immediate (well under half a second for a typical Recording), so that dictating is quicker than typing.

### Island

20. As a user, I want an Island to grow out of the notch when a Dictation starts, so that I can see at a glance that Parlez is listening.
21. As a user, I want the Island to show a live level meter driven by my voice while recording, so that I know the microphone is actually hearing me.
22. As a user, I want the Island to show a spinner while the Transcript is being produced, so that I know it's working.
23. As a user, I want the Island to shake when I press the Dictation shortcut and it can't start (busy, or Setup not finished), so that I understand why nothing happened.
24. As a user, I want the Island to show a short red message when something goes wrong (a missing permission, a failed transcription), so that I know what to fix.
25. As a user, I want the Island to collapse back into the notch when the Dictation is done, so that it gets out of my way.
26. As a user with no notch on the current screen (lid closed or an external main display), I want the Island to float at the top centre of that screen, so that the feedback works everywhere.

### Menu bar

27. As a user, I want a menu-bar icon as Parlez's home, so that I can reach Settings, Copy last Transcript and Quit.
28. As a user, I want Parlez to have no Dock icon, so that it stays out of the way.

### Settings

29. As a user, I want to set the Dictation shortcut in Settings by pressing the key combination I want, so that it fits my habits and doesn't clash with other apps.
30. As a user, I want ⌃⌥Space as the default Dictation shortcut, so that it works before I change anything.
31. As a user, I want a "Launch at login" setting, so that Parlez is always there when I need it.
32. As a user, I want Settings to hold nothing else, so that there is nothing to configure that I didn't ask for.

### Setup

33. As a new user, I want a Setup window on first launch, so that I'm walked through everything Parlez needs before I first use it.
34. As a new user, I want Setup to ask for microphone permission, so that Parlez can hear me.
35. As a new user, I want Setup to explain Accessibility permission and open the right System Settings pane with one button, so that pasting works without me hunting through settings.
36. As a new user, I want Setup to download and prepare the speech model with a progress bar, so that the ~20 s first-load cost is paid before my first Dictation, not during it.
37. As a new user, I want Setup to detect when each permission has been granted and move on, so that I don't have to restart the app.
38. As a user, I want the Dictation shortcut to be unavailable until Setup is complete, so that a half-set-up app never fails silently.
39. As a user, I want Setup to reopen at the model step if the model has gone missing (for example, a cleared cache), so that Parlez repairs itself instead of breaking.
40. As a user, I want Setup to reopen at the right step if I later revoke a permission, so that I'm told what to fix.

### Building and sharing

41. As the developer, I want to build, sign and install Parlez with one script, so that rebuilding is quick and repeatable.
42. As the developer, I want my builds signed with my Apple Development certificate, so that macOS keeps my microphone and Accessibility permissions across rebuilds.
43. As the developer, I want to work entirely from VS Code with a Swift package, so that I never have to open Xcode.
44. As a friend, I want to download a zip from GitHub Releases, drag Parlez into Applications and open it, so that I don't have to build or sign anything.
45. As a friend, I want the README to explain the one-time "Open Anyway" step in Privacy & Security, so that I can get past Gatekeeper on an app that isn't notarised.
46. As a friend, I want to update by downloading a newer release, so that updating is obvious even without an auto-updater.
47. As the developer, I want the project MIT-licensed, with a "Powered by Desert Ant Labs" credit and a link to the Voz license in the README, so that sharing is clear and complies with Voz's license.

## Implementation Decisions

- **Speech engine**: Voz from Desert Ant Labs' `desert-ant-core` Swift package (ADR-0001). Batch transcription of the whole Recording after the Dictation stops, by passing mono samples at the microphone's sample rate and letting Voz resample. No language parameter (Voz has none) and no vocabulary list (the spike found it barely helps). The model is loaded once at launch and kept in memory: about 0.3 s from cache, ~20 s on the very first load after download.
- **Modules**:
  - **Dictation core**: the one deep module. It owns every rule about when a Dictation starts, stops, cancels, is skipped, is ignored, and what gets inserted. Its interface is small: it takes events (Dictation shortcut pressed, Esc pressed, microphone level, time passing, Transcript ready or failed, Setup complete or incomplete) and exposes a single observable state (unavailable, idle, recording with level, transcribing) plus short-lived signals (busy shake, error message). It also holds the last Transcript. It has no UI and no direct OS calls.
  - **Microphone adapter**: starts and stops audio capture, delivers the samples at the end and a level reading while recording.
  - **Transcriber adapter**: wraps Voz. Turns samples into a Transcript.
  - **Inserter adapter**: saves the clipboard, puts the Transcript on it, sends ⌘V, then restores the clipboard after a short delay so the target app has read it.
  - **Clock adapter**: the time source for the 0.3 s minimum, the 30 s silence limit and the 10-minute limit.
  - **Island**: a borderless, non-activating panel drawn around the notch of the screen with the active menu bar, or at the top centre if that screen has no notch. It only renders the Dictation core's state.
  - **Menu bar**: a menu-bar item with Settings, Copy last Transcript and Quit. The app runs as an agent app with no Dock icon.
  - **Settings**: a window with the Dictation shortcut recorder and Launch at login.
  - **Setup**: a window with three steps (Microphone, Accessibility, model download and preparation, using Voz's download progress). It tells the Dictation core when Setup is complete or incomplete.
- **Dictation shortcut**: registered through the `KeyboardShortcuts` package (MIT), which provides the recorder control, stores the choice and registers a global hotkey with no permission required. Combinations only; a lone Fn or modifier key is not supported. Default ⌃⌥Space.
- **Esc**: registered as a global hotkey only while recording, and unregistered when the Dictation ends.
- **Silence detection**: based on the microphone level the Island's meter already uses, not on Voz. A Dictation stops after 30 s continuously below a silence threshold. The threshold is a constant tuned by hand against a real microphone.
- **Permissions**: Microphone (with a usage description) and Accessibility (for posting the ⌘V). Global hotkeys themselves need none.
- **Project shape**: a Swift package (tools 6.2+, macOS 15+) with a library target for everything except the app entry point, an executable target for the app, and a test target. A build/install script assembles the `.app` bundle (agent-app flag, microphone usage description, bundle identifier), signs it, and copies it to Applications. It signs with the developer's Apple Development identity when present and falls back to ad-hoc signing. A release mode zips the bundle for GitHub Releases.
- **Distribution**: not notarised (v1). Users update by hand from GitHub Releases. Telemetry from the Voz SDK is accepted and left untouched, as its license requires.
- **App name**: Parlez.

## Testing Decisions

- **One seam: the Dictation core.** Tests drive it only through its public interface (send events, read the state and signals) with fake Microphone, Transcriber, Inserter and Clock adapters. A good test states a rule from this spec in user terms ("a press while transcribing is ignored and signals busy") and checks the observable outcome (state, signal, what the fake Inserter received), never the order of internal calls.
- **Covered by tests**: start and stop toggling; insertion of the Transcript; skipping Recordings under 0.3 s; nothing inserted for an empty Transcript; Esc cancelling; the 30 s silence stop and the 10-minute stop both transcribing and inserting; a press while transcribing being ignored with a busy signal; a transcription failure producing an error signal and inserting nothing; the last Transcript being kept for "Copy last Transcript"; the shortcut being ignored with a busy signal before Setup is complete.
- **Framework**: Swift's built-in `Testing` framework, run with `swift test`. There is no prior art in this repo. The spike on branch `prototype/voz-spike` is throwaway and has no tests.
- **Checked by hand, against a short checklist in the README**: the global Dictation shortcut and Esc in real apps (a browser, Slack, VS Code, a terminal), the paste and clipboard restore, the Island on the notch and on an external display, the Setup flow on a fresh user account, Launch at login, and the release zip opening on another Mac via "Open Anyway". These are thin wrappers around macOS, so automated tests would only test mocks.

## Out of Scope

- Hold-to-talk mode.
- A single-modifier or Fn Dictation shortcut.
- Streaming partial text into the target app while talking.
- Mixing English and Dutch in one sentence: the spike showed it is unreliable, so it is not designed for.
- Any cleanup or rewriting of the Transcript (filler removal, LLM polish). Voz already drops fillers. No Uhm model.
- A custom vocabulary setting.
- Language selection.
- Typing the Transcript as keystrokes instead of pasting.
- Notarisation, a Developer ID, Homebrew, and an auto-updater.
- Sounds on start and stop.
- A history of Transcripts beyond the last one.

## Further Notes

- The spike lives on branch `prototype/voz-spike` and is not merged; its `VERDICT.md` holds the measurements (~7 s Recordings transcribe in 115–145 ms on an M3 Pro; cached model load 0.29 s; Voz drops fillers; mixed-language and vocabulary results). ADR-0001 records why Voz was chosen and what the spike confirmed.
- Use the glossary terms throughout: Dictation, Dictation shortcut, Recording, Transcript, Caret, Island, Setup.
- The Voz SDK contacts `events.desertant.com` whenever the model loads. That is expected, not a bug.

## Comments

- 2026-10-30: Merged on `parlez/integration` (review fixes at 9b2f024). Automated checks pass (29 tests). "By hand" criteria await verification per the README hand-check checklist.
