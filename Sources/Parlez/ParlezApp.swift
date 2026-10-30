import KeyboardShortcuts
import ParlezKit
import SwiftUI

@main
struct ParlezApp: App {
    let dictation: Dictation
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
        }
        self.dictation = dictation
        setup = Setup(dictation: dictation, transcriber: transcriber)
        setup.start()
    }

    var body: some Scene {
        MenuBarExtra("Parlez", systemImage: "waveform") {
            SettingsMenuItem()
            Button("Copy last Transcript") {
                guard let transcript = dictation.lastTranscript else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(transcript, forType: .string)
            }
            .disabled(dictation.lastTranscript == nil)
            Divider()
            Button("Quit Parlez") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        Settings { SettingsView() }
    }
}
