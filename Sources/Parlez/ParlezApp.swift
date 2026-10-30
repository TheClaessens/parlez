import KeyboardShortcuts
import ParlezKit
import SwiftUI

@main
struct ParlezApp: App {
    let dictation: Dictation
    let island: Island
    let setup: Setup
    let retoucher = makeRetoucher()

    init() {
        let microphone = AudioMicrophone()
        let transcriber = VozTranscriber()
        let dictation = Dictation(
            microphone: microphone, transcriber: transcriber, inserter: PasteInserter(), retoucher: retoucher)
        let setup = Setup(dictation: dictation, transcriber: transcriber)
        microphone.onLevel = { level in Task { await dictation.microphoneLevel(level) } }
        for (name, shortcut) in [(KeyboardShortcuts.Name.dictation, Dictation.Shortcut.dictation), (.retouche, .retouche)] {
            KeyboardShortcuts.onKeyDown(for: name) {
                Task { @MainActor in
                    await dictation.shortcutPressed(shortcut)
                    // The Island says "Finish Setup"; show where to finish it.
                    if dictation.state == .unavailable { setup.show() }
                }
            }
        }
        KeyboardShortcuts.onKeyDown(for: .cancelDictation) {
            Task { @MainActor in dictation.escPressed() }
        }
        KeyboardShortcuts.disable(.cancelDictation)
        // After `onKeyDown`, which registers the Retouche shortcut whether or not it is wanted.
        SettingsView.applyRetouche(to: dictation)
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
        self.setup = setup
        setup.start()
    }

    var body: some Scene {
        MenuBarExtra {
            SettingsMenuItem()
            Button("Copy last Transcript") {
                if let transcript = dictation.lastTranscript { PasteInserter.copy(transcript) }
            }
            .disabled(dictation.lastTranscript == nil)
            Divider()
            Button("Quit Parlez") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            MenuBarIcon(dictation: dictation)
        }
        Settings { SettingsView(dictation: dictation, retoucher: retoucher) }
    }
}

/// The menu bar icon, red while recording.
struct MenuBarIcon: View {
    let dictation: Dictation

    var body: some View {
        // The menu bar draws images as monochrome templates, so the red one is an NSImage that opts out.
        let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Parlez")!
        if dictation.state == .recording, let red = image.withSymbolConfiguration(.init(paletteColors: [.systemRed])) {
            red.isTemplate = false
            return Image(nsImage: red)
        }
        return Image(nsImage: image)
    }
}

/// Parlez has no Dock icon, so it activates itself before opening a window, or the window stays behind.
@MainActor func bringToFront(_ open: () -> Void) {
    NSApp.activate()
    open()
}
