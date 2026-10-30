import KeyboardShortcuts
import ParlezKit
import SwiftUI

@main
struct ParlezApp: App {
    let dictation: Dictation
    let island: Island
    let setup: Setup

    init() {
        let microphone = AudioMicrophone()
        let transcriber = VozTranscriber()
        let dictation = Dictation(microphone: microphone, transcriber: transcriber, inserter: PasteInserter())
        microphone.onLevel = { level in Task { await dictation.microphoneLevel(level) } }
        KeyboardShortcuts.onKeyDown(for: .dictation) {
            Task { await dictation.shortcutPressed() }
        }
        KeyboardShortcuts.onKeyDown(for: .cancelDictation) {
            Task { @MainActor in dictation.escPressed() }
        }
        KeyboardShortcuts.disable(.cancelDictation)
        dictation.onRecordingChanged = { recording in
            if recording { KeyboardShortcuts.enable(.cancelDictation) } else { KeyboardShortcuts.disable(.cancelDictation) }
            // Time passing, so the automatic stops still happen if the Microphone stops sending levels.
            guard recording else { return }
            Task {
                while dictation.state == .recording {
                    try? await Task.sleep(for: .seconds(1))
                    await dictation.tick()
                }
            }
        }
        self.dictation = dictation
        island = Island(dictation: dictation)
        setup = Setup(dictation: dictation, transcriber: transcriber)
        setup.start()
    }

    var body: some Scene {
        MenuBarExtra("Parlez", systemImage: "waveform") {
            SettingsMenuItem()
            Button("Copy last Transcript") {
                if let transcript = dictation.lastTranscript { PasteInserter.copy(transcript) }
            }
            .disabled(dictation.lastTranscript == nil)
            Divider()
            Button("Quit Parlez") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        Settings { SettingsView() }
    }
}

/// Parlez has no Dock icon, so it activates itself before opening a window, or the window stays behind.
@MainActor func bringToFront(_ open: () -> Void) {
    NSApp.activate()
    open()
}
