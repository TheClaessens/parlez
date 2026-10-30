import AppKit
import Carbon.HIToolbox

/// The Inserter adapter: pastes the Transcript at the Caret with ⌘V, then puts the clipboard back.
@MainActor public final class PasteInserter: Inserter {
    /// How long the target app gets to read the pasteboard before it is restored.
    private let restoreDelay: Duration

    public init(restoreDelay: Duration = .milliseconds(500)) {
        self.restoreDelay = restoreDelay
    }

    public func insert(_ transcript: String) {
        let pasteboard = NSPasteboard.general
        let saved = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
        pasteboard.clearContents()
        pasteboard.setString(transcript, forType: .string)
        let ours = pasteboard.changeCount
        pressCommandV()

        Task {
            try? await Task.sleep(for: restoreDelay)
            // Leave the clipboard alone if something else was copied in the meantime.
            guard pasteboard.changeCount == ours else { return }
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
}
