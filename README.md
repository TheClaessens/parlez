# Parlez

Dictation for macOS that runs on your Mac and lives in the menu bar. Press the Dictation shortcut (⌃⌥Space by default) and talk, in English or Dutch. Press it again and the Transcript is pasted at the Caret of whatever app you are typing in. Your clipboard is put back afterwards. While you talk, the Island grows out of the notch and shows a level meter. Esc cancels. A Dictation stops by itself after 30 s of silence or 10 minutes.

Speech is turned into text on your Mac by [Voz](https://github.com/Desert-Ant-Labs/desert-ant-core). No audio leaves the machine.

Requires macOS 15 or later on Apple silicon.

## Install from a release

1. Download `Parlez-<version>.zip` from [Releases](../../releases), unzip it, and drag `Parlez.app` into Applications.
2. Open it. Parlez is not notarised, so macOS blocks the first open. Go to System Settings → Privacy & Security, scroll down to the message about Parlez, click **Open Anyway** and confirm. On macOS 15 and later, right-click → Open no longer gets around this.
3. Setup opens. Grant the microphone, grant Accessibility (Parlez needs it to paste), and let it download the speech model (about 467 MB, once). When Setup is done, the Dictation shortcut works.

Settings (in the menu-bar menu) lets you change the Dictation shortcut and turn on Launch at login.

## Update

There is no auto-updater. Download the newer zip from Releases, quit Parlez, and replace `Parlez.app` in Applications. You will need **Open Anyway** again. Because each release is signed differently, macOS also forgets the Accessibility grant: in System Settings → Privacy & Security → Accessibility, remove Parlez, then grant it again when Setup asks.

## Build from source

You need Xcode 26 or later: it brings Swift 6.2 and `actool`, which compiles the app icon from `brand/Parlez.icon`.

```sh
swift test                      # run the tests
scripts/build.sh                # build, sign and install into /Applications
scripts/build.sh --build-only   # build and sign into build/Parlez.app only
scripts/build.sh --release      # build and sign, then zip into build/Parlez-<version>.zip
```

The script signs with the first Apple Development identity in your keychain, so macOS keeps the permissions across rebuilds, and falls back to ad-hoc signing if there is none. Set `PARLEZ_SIGN_IDENTITY` to choose an identity, or to `-` for ad-hoc.

To publish a release, bump `version` in `scripts/build.sh`, run `scripts/build.sh --release`, and upload the zip to a GitHub release.

## Hand-check checklist

The Dictation core is covered by `swift test`. Everything below wraps macOS and is checked by hand before a release.

- [ ] **Dictation and paste**: in TextEdit, a browser, Slack, VS Code and a terminal, ⌃⌥Space → speak → ⌃⌥Space pastes the Transcript at the Caret, and the clipboard still holds what was there before.
- [ ] **Clipboard restore delay** (`PasteInserter.restoreDelay`, 0.5 s): in slow apps (an Electron app such as Slack or VS Code, and a remote desktop session), the Transcript is pasted, not the old clipboard contents.
- [ ] **Esc**: Esc during a Dictation cancels it and nothing is pasted. Afterwards, Esc works normally in other apps.
- [ ] **Silence threshold** (`Dictation.silenceThreshold`): normal speaking, including thinking pauses, never counts as silence, and 30 s in a quiet room stops the Dictation. While silent the waveform is still dots; for the last 10 s an amber ring counts down under the notch with "No speech · stopping in N s", gone the moment you speak again. The same countdown reads "Time limit · stopping in N s" in the last 10 s before 10 minutes. Either automatic stop still pastes.
- [ ] **Waveform** (`IslandView.meterGain`): the Island's waveform moves clearly with normal speech, its bars don't move as one block, it doesn't sit pinned at full, and it stays low in a quiet room.
- [ ] **Island**: on the built-in display it stays the height of the notch while recording, with a pulsing red dot and the running time left of the notch and the waveform right of it; its top corners curve into the screen edge. On stop it keeps that shape: the time freezes, the dot becomes a spinner and the waveform a shimmer. A retouched stop skips the spinner and goes straight to the Retouche stage until the paste: a twinkling star and "Retouche" in indigo left of the notch, the shimmer in indigo right of it. That holds for every stop with Retouche on the Dictation shortcut, and for a stop by the Retouche shortcut, including a Dictation started with the Dictation shortcut. It springs between sizes, and a message drops a row below the notch. With an external display as main (or the lid closed) the same content, the Retouche stage included, floats in a pill at the top centre. The menu bar icon is red while recording. It never takes focus from the app being dictated into.
- [ ] **Confirmations**: every ending drops a row below the notch (or fills the floating pill) for about 1.5 s, then the Island collapses: a paste shows a green check and "Pasted · N words" with the right count, Esc shows "Cancelled · nothing pasted", and a Dictation with no speech shows "Nothing heard". A retouched paste shows "Pasted · N words · retouched" with "retouched" in indigo; a Retouche that fell back shows a grey outlined check and "Pasted as spoken · Retouche skipped". Check both on the built-in display and in the floating pill on an external one. A quick double-tap shows nothing, and starting a new Dictation during a confirmation clears it at once.
- [ ] **Settings**: "Settings…" opens the window in front. A new Dictation shortcut works straight away and survives a restart.
- [ ] **Remove fillers setting**: below Launch at login, after a divider, the "Remove fillers" switch with its "beta" badge and caption is off by default, and works on macOS 15. Turned on for the first time (`rm -rf ~/Library/Caches/desert-ant-models/desert-ant-labs/uhm` first), a progress bar shows the 45 MB download, then disappears; Dictations during the download paste Voz's Transcript unchanged. With the network off, turning it on shows "The download failed. Check your connection." and "Try again", which downloads once the network is back. The switch survives a restart, and with the model on disk launch loads it without a download or progress bar; with the switch on and the model deleted, launch downloads it. Setup is unchanged.
- [ ] **Remove fillers Dictations**: with the switch on, dictating "So uh we ship on um Monday." pastes "So we ship on Monday.", "Pasted · N words" counts the words pasted, and "Copy last Transcript" copies that. A few real Dictations with fillers in English, in Dutch and mixed lose the "uh"s Voz let through and nothing else, and a Dictation without fillers pastes exactly as with the switch off. A sentence with a real "and" next to a pause ("I bought bread … and milk") keeps its "and". A Dictation that was only "uhm" shows "Nothing heard". There is no extra wait on the Island. With Retouche on as well, a self-correction with fillers pastes only the corrected version, fillers gone.
- [ ] **Retouche setting**: below Remove fillers, after a divider, the "Retouche" switch with its "beta" badge and caption is off by default; turned on it survives a restart. Once on, "Use a separate shortcut for Retouche" appears below it; once checked, the "Retouche shortcut:" recorder (⌃⌥Z) and its caption appear; both survive a restart. Where Retouche can't run the switch is greyed out, keeps its stored position, the checkbox and recorder are hidden, and an info line gives the reason followed by "Until then every Dictation pastes your exact words, and your Retouche shortcut works as a plain Dictation shortcut.": "This Mac doesn't support Apple Intelligence." on an ineligible Mac, "Turn on Apple Intelligence in System Settings to use Retouche." with Apple Intelligence off, the not-ready note while the model downloads, and "Needs macOS 26." on macOS 15. Dictations there paste the plain Transcript.
- [ ] **Retouche Dictations**: with Retouche on, dictating "The button should be red. Oh wait, actually the button should be green." pastes "The button should be green.", and "Copy last Transcript" copies that. A few real Dictations with self-corrections in English and in Dutch ("om drie uur, nee, om vier uur") paste only the corrected version, fillers dropped, nothing else reworded, and text with nothing to fix pastes unchanged. A dictated request ("Write an email to Sam saying…") pastes as the words said, never as an email. An automatic stop (30 s of silence) is retouched too, Esc still cancels, and a press while Retouche runs shakes the Island with "Still retouching · one moment".
- [ ] **Retouche shortcut**: with "Use a separate shortcut for Retouche" checked, in TextEdit, a browser and Slack, ⌃⌥Space → self-correct → ⌃⌥Space pastes the words exactly as said, and ⌃⌥Z → self-correct → ⌃⌥Z pastes the Retouched Transcript. Starting with ⌃⌥Space and stopping with ⌃⌥Z retouches; starting with ⌃⌥Z and stopping with ⌃⌥Space doesn't. A 30 s silence stop isn't retouched, Esc cancels a Dictation either shortcut started, and a new Retouche shortcut works straight away. Unchecked (or Retouche off), ⌃⌥Z does nothing in Parlez and reaches the frontmost app again (Undo in TextEdit). Where Retouche can't run, ⌃⌥Z still starts and stops a plain Dictation.
- [ ] **Launch at login**: the toggle registers Parlez as a login item (check System Settings → General → Login Items), and Parlez starts after logging out and back in.
- [ ] **Setup from a clean state** (a fresh user account, or `tccutil reset All com.thomasclaessens.parlez` and `rm -rf ~/Library/Caches/desert-ant-models`): Setup opens at the first missing step, moves on and comes back to the front as each permission is granted without a restart, shows the model download progress, and the first Dictation afterwards is fast. Pressing the Dictation shortcut before Setup is done shows "Finish Setup to dictate" on the Island and brings Setup to the front. Revoking a permission or removing the model later reopens Setup at that step.
- [ ] **Menu bar icon**: the Parlez mark (three bars and a caret) sits in the menu bar and follows a light and a dark menu bar. It turns fully red while recording and back when the Dictation stops, and it is dimmed until Setup is finished.
- [ ] **App icon**: after `scripts/build.sh`, Parlez.app in Finder shows the mark: ink bars and an indigo caret on white. With dark icons (System Settings → Appearance → Icon & widget style) it turns dark with light bars, and the tinted style follows the tint. On macOS 15, if one is available, it shows the same icon, flat.
- [ ] **Release zip**: on another Mac, the zip from `scripts/build.sh --release` unpacks, opens after **Open Anyway**, and completes Setup.

## Credits and licenses

Parlez is MIT-licensed, see [LICENSE](LICENSE).

Powered by Desert Ant Labs. Voz is used under the [Desert Ant Labs Source-Available License 1.0](https://license.desertant.com/1.0). As that license requires, the Voz SDK is left as it is: it pings `events.desertant.com` each time the model loads, to count devices. No audio or text is sent.

The Dictation shortcut uses [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (MIT).
