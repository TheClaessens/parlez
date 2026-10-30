import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The Dictation shortcut, ⌃⌥Space unless changed.
    public static let dictation = Self("dictation", default: .init(.space, modifiers: [.control, .option]))

    /// The Retouche shortcut, ⌃⌥Z unless changed. Registered only while Retouche has its own shortcut.
    public static let retouche = Self("retouche", default: .init(.z, modifiers: [.control, .option]))

    /// Esc, which cancels a Dictation. Registered only while recording, so other apps keep Esc otherwise.
    public static let cancelDictation = Self("cancelDictation", default: .init(.escape))
}
