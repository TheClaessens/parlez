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
        Self.applyRetouche(to: dictation)
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
        setup.applyRemoveFillers()
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
        Settings { SettingsView(dictation: dictation, setup: setup, retoucher: retoucher) }
    }
}

/// The menu bar icon: the Parlez mark, red while recording and dimmed until Setup is finished.
struct MenuBarIcon: View {
    let dictation: Dictation

    var body: some View {
        // The menu bar draws images as monochrome templates, so the red one opts out.
        switch dictation.state {
        case .recording: Image(nsImage: Self.mark(.systemRed, template: false))
        case .unavailable: Image(nsImage: Self.mark(.black.withAlphaComponent(0.35)))
        default: Image(nsImage: Self.mark(.black))
        }
    }

    /// The rounded rectangles of `brand/parlez-mark.svg` (x, y, width, height on its 24-unit grid): three bars, then the caret.
    static let shapes: [(Double, Double, Double, Double)] = [
        (2.75, 8.75, 2.5, 6.5), (6.75, 5.75, 2.5, 12.5), (10.75, 7.75, 2.5, 8.5),
        (14.75, 2.75, 6.5, 2.5), (16.75, 2.75, 2.5, 18.5), (14.75, 18.75, 6.5, 2.5),
    ]

    /// The mark at 18 pt, showing the grid's square from (1.5, 1.5) to (22.5, 22.5) like the SVG.
    static func mark(_ color: NSColor, template: Bool = true) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let scale = 18 / 21.0, radius = 1.25 * scale
            // One path, filled once, so the caret's overlapping parts don't darken when dimmed.
            let path = NSBezierPath()
            for (x, y, width, height) in shapes {
                let rect = NSRect(x: (x - 1.5) * scale, y: (y - 1.5) * scale, width: width * scale, height: height * scale)
                path.append(NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius))
            }
            color.setFill()
            path.fill()
            return true
        }
        image.isTemplate = template
        image.accessibilityDescription = "Parlez"
        return image
    }
}

/// Parlez has no Dock icon, so it activates itself before opening a window, or the window stays behind.
@MainActor func bringToFront(_ open: () -> Void) {
    NSApp.activate()
    open()
}
