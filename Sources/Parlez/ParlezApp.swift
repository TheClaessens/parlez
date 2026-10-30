import KeyboardShortcuts
import ParlezKit
import SwiftUI

@main
struct ParlezApp: App {
    init() {
        let microphone = AudioMicrophone()
        let dictation = Dictation(microphone: microphone, transcriber: VozTranscriber(), inserter: PasteInserter())
        microphone.onLevel = { level in Task { await dictation.microphoneLevel(level) } }
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
