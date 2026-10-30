import KeyboardShortcuts
import ParlezKit
import SwiftUI

@main
struct ParlezApp: App {
    init() {
        let dictation = Dictation(microphone: AudioMicrophone(), transcriber: VozTranscriber(), inserter: PasteInserter())
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
    }

    var body: some Scene {
        MenuBarExtra("Parlez", systemImage: "waveform") {
            SettingsMenuItem()
            Divider()
            Button("Quit Parlez") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        Settings { SettingsView() }
    }
}
