import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The Dictation shortcut, ⌃⌥Space unless changed.
    public static let dictation = Self("dictation", default: .init(.space, modifiers: [.control, .option]))
}

extension KeyboardShortcuts.Name {
    /// Esc, which cancels a Dictation. Registered only while recording, so other apps keep Esc otherwise.
    public static let cancelDictation = Self("cancelDictation", default: .init(.escape))
}
