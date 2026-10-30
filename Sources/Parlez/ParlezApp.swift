import KeyboardShortcuts
import ParlezKit
import SwiftUI

@main
struct ParlezApp: App {
    let dictation: Dictation

    init() {
        let dictation = Dictation(microphone: AudioMicrophone(), transcriber: VozTranscriber(), inserter: PasteInserter())
        KeyboardShortcuts.onKeyDown(for: .dictation) {
            Task { await dictation.shortcutPressed() }
        }
        self.dictation = dictation
    }

    var body: some Scene {
        MenuBarExtra("Parlez", systemImage: "waveform") {
            Button("Copy last Transcript") {
                guard let transcript = dictation.lastTranscript else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(transcript, forType: .string)
            }
            .disabled(dictation.lastTranscript == nil)
            Button("Quit Parlez") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
