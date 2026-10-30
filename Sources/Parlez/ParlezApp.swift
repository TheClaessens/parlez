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
    }

    var body: some Scene {
        MenuBarExtra("Parlez", systemImage: "waveform") {
            Button("Quit Parlez") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
