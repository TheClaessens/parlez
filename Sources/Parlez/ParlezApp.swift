import KeyboardShortcuts
import ParlezKit
import SwiftUI

@main
struct ParlezApp: App {
    let dictation: Dictation
    let island: Island

    init() {
        let microphone = AudioMicrophone()
        let dictation = Dictation(microphone: microphone, transcriber: VozTranscriber(), inserter: PasteInserter())
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
        island = Island(dictation: dictation)
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
