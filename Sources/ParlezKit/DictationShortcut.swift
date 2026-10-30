import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The Dictation shortcut, ⌃⌥Space unless changed.
    public static let dictation = Self("dictation", default: .init(.space, modifiers: [.control, .option]))
}
