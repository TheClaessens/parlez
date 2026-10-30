import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// The Inserter adapter: pastes the Transcript at the Caret with ⌘V, then puts the clipboard back.
@MainActor public final class PasteInserter: Inserter {
    /// How long the target app gets to read the pasteboard before it is restored.
    /// ponytail: fixed; slow apps (Electron, remote desktop) may need longer, see the README checklist.
    static let restoreDelay: Duration = .milliseconds(500)

    public init() {}

    /// Puts the Transcript on the clipboard, replacing what was there. Returns the pasteboard's change count after.
    @discardableResult public static func copy(_ transcript: String) -> Int {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
        return NSPasteboard.general.changeCount
    }

    public func insert(_ transcript: String) throws {
        // Without Accessibility the ⌘V would go nowhere: leave the Transcript on the clipboard instead.
        guard AXIsProcessTrusted() else {
            Self.copy(transcript)
            throw NotTrusted()
        }
        let pasteboard = NSPasteboard.general
        let saved = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
        let transcriptChangeCount = Self.copy(transcript)
        pressCommandV()

        Task {
            try? await Task.sleep(for: Self.restoreDelay)
            // Leave the clipboard alone if something else was copied in the meantime.
            guard pasteboard.changeCount == transcriptChangeCount else { return }
            pasteboard.clearContents()
            pasteboard.writeObjects(saved)
        }
    }

    private func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }

    private struct NotTrusted: Error {}
}
