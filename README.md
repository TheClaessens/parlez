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

You need Xcode's command-line tools with Swift 6.2 or later.

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
- [ ] **Esc**: Esc during a Dictation cancels it and nothing is pasted. Afterwards, Esc works normally in other apps.
- [ ] **Silence threshold** (`Dictation.silenceThreshold`): normal speaking, including thinking pauses, never counts as silence, and 30 s in a quiet room stops the Dictation.
- [ ] **Level meter** (`IslandView.meterGain`): the Island's meter moves clearly with normal speech, doesn't sit pinned at full, and stays low in a quiet room.
- [ ] **Island**: on the built-in display it grows out of the notch. With an external display as main (or the lid closed) it floats at the top centre. It never takes focus from the app being dictated into.
- [ ] **Settings**: "Settings…" opens the window in front. A new Dictation shortcut works straight away and survives a restart.
- [ ] **Launch at login**: the toggle registers Parlez as a login item (check System Settings → General → Login Items), and Parlez starts after logging out and back in.
- [ ] **Setup from a clean state** (a fresh user account, or `tccutil reset All com.thomasclaessens.parlez` and `rm -rf ~/Library/Caches/desert-ant-models`): Setup opens at the first missing step, moves on as each permission is granted without a restart, shows the model download progress, and the first Dictation afterwards is fast. Revoking a permission or removing the model later reopens Setup at that step.
- [ ] **Release zip**: on another Mac, the zip from `scripts/build.sh --release` unpacks, opens after **Open Anyway**, and completes Setup.

## Credits and licenses

Parlez is MIT-licensed, see [LICENSE](LICENSE).

Powered by Desert Ant Labs. Voz is used under the [Desert Ant Labs Source-Available License 1.0](https://license.desertant.com/1.0). As that license requires, the Voz SDK is left as it is: it pings `events.desertant.com` each time the model loads, to count devices. No audio or text is sent.

The Dictation shortcut uses [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (MIT).
