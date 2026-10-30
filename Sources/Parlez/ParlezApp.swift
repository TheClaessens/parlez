import KeyboardShortcuts
import ParlezKit
import SwiftUI

@main
struct ParlezApp: App {
    let dictation: Dictation
    let island: Island
    let setup: Setup
    let transcriber: VozTranscriber
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
        Self.applyRetouche(to: dictation)
        Self.applyRemoveFillers(to: transcriber, download: false)
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
        self.transcriber = transcriber
        setup.start()
    }

    static let retoucheKey = "retouche"
    static let ownShortcutKey = "retoucheOwnShortcut"

    /// Hands the stored Retouche settings to the Dictation core, and registers the Retouche shortcut only while
    /// Retouche is on with its own shortcut. It stays registered while the Retoucher is unavailable: the core
    /// then treats it as a plain Dictation shortcut.
    static func applyRetouche(to dictation: Dictation) {
        let defaults = UserDefaults.standard
        let on = defaults.bool(forKey: retoucheKey), own = defaults.bool(forKey: ownShortcutKey)
        dictation.retouche = !on ? .off : own ? .onOwnShortcut : .onDictationShortcut
        if on && own { KeyboardShortcuts.enable(.retouche) } else { KeyboardShortcuts.disable(.retouche) }
    }

    static let removeFillersKey = "removeFillers"

    /// Hands the stored Remove fillers setting to the Transcriber and, while it is on, prepares Uhm's model.
    /// At launch (`download: false`) only a model already on disk is loaded, so launch never downloads.
    static func applyRemoveFillers(to transcriber: VozTranscriber, download: Bool) {
        let on = UserDefaults.standard.bool(forKey: removeFillersKey)
        transcriber.removesFillers = on
        if on, download || transcriber.isFillerModelDownloaded { Task { await transcriber.prepareFillerModel() } }
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
        Settings { SettingsView(dictation: dictation, transcriber: transcriber, retoucher: retoucher) }
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
