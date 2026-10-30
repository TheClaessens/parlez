import Observation

/// The audio captured between the start and the stop of a Dictation.
public struct Recording: Sendable {
    public var samples: [Float]
    public var sampleRate: Double
    public init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
    }
}

@MainActor public protocol Microphone: AnyObject {
    func start() throws
    func stop() -> Recording
}

@MainActor public protocol Transcriber: AnyObject {
    func transcribe(_ recording: Recording) async throws -> String
}

@MainActor public protocol Inserter: AnyObject {
    /// Pastes the Transcript at the Caret. Throws when it cannot paste, leaving the Transcript on the clipboard.
    func insert(_ transcript: String) throws
}

/// The Dictation core: every rule about when a Dictation starts, stops and what gets inserted.
/// It makes no OS calls of its own; it only talks to the adapters it is given.
@MainActor @Observable
public final class Dictation {
    /// `unavailable` while Setup is not complete.
    public enum State: Equatable, Sendable { case unavailable, idle, recording, transcribing }

    /// A short-lived signal for the Island. Each one raised is a new value (its `raised` instant differs),
    /// so the Island can react to every raise and decide how long to show it.
    public struct Signal: Equatable, Sendable {
        public enum Kind: Equatable, Sendable { case busy, setupUnfinished, error(String) }
        public let kind: Kind
        public let raised: ContinuousClock.Instant
    }

    public private(set) var state: State = .unavailable {
        didSet {
            let recording = state == .recording
            guard recording != (oldValue == .recording) else { return }
            // However a recording ends (stop, automatic stop, Esc), drop its silence/length tracking.
            if !recording { silentSince = nil; startedAt = nil; level = 0 }
            onRecordingChanged?(recording)
        }
    }
    /// The latest Microphone level while recording (for the Island's meter); 0 otherwise.
    public private(set) var level: Float = 0
    /// Called with true when a Dictation starts recording and false when it leaves recording, however it ends.
    /// The app registers Esc as the cancel shortcut only in between.
    @ObservationIgnored public var onRecordingChanged: (@MainActor (Bool) -> Void)?
    /// The last signal raised; cleared when the next Dictation starts.
    public private(set) var signal: Signal?
    /// Kept for "Copy last Transcript".
    public private(set) var lastTranscript: String?

    /// A Recording shorter than this is an accidental tap and is thrown away.
    public static let minimumRecording: Duration = .milliseconds(300)

    private let microphone: any Microphone
    private let transcriber: any Transcriber
    private let inserter: any Inserter
    /// Reads the current instant (injected so tests control time), for the silence and length limits
    /// and the 0.3 s minimum.
    private let now: @MainActor () -> ContinuousClock.Instant
    private var startedAt: ContinuousClock.Instant?
    /// When the current run of readings below `silenceThreshold` began; nil while there is sound.
    private var silentSince: ContinuousClock.Instant?

    /// Microphone level (RMS of the samples, 0...1) below which a reading counts as silence.
    /// ponytail: tuned by hand against one built-in mic; make it a setting if other mics misjudge it.
    public static let silenceThreshold: Float = 0.01
    public static let silenceLimit: Duration = .seconds(30)
    public static let lengthLimit: Duration = .seconds(10 * 60)

    public init(
        microphone: any Microphone,
        transcriber: any Transcriber,
        inserter: any Inserter,
        now: @escaping @MainActor () -> ContinuousClock.Instant = { .now }
    ) {
        self.microphone = microphone
        self.transcriber = transcriber
        self.inserter = inserter
        self.now = now
    }

    /// The Dictation shortcut was pressed: start a Dictation, or stop it and insert its Transcript.
    public func shortcutPressed() async {
        switch state {
        case .idle:
            guard (try? microphone.start()) != nil else { return raise(.error("Microphone didn't start")) }
            startedAt = now()
            signal = nil
            state = .recording
        case .recording:
            await stop()
        case .unavailable:
            raise(.setupUnfinished)
        case .transcribing:
            raise(.busy)
        }
    }

    /// Setup is complete: the Dictation shortcut becomes available.
    public func setupCompleted() {
        if state == .unavailable { state = .idle }
    }

    /// Setup is incomplete again (a permission was revoked): the Dictation shortcut becomes unavailable.
    /// A recording Dictation is thrown away; one already transcribing still inserts its Transcript.
    public func setupIncomplete() {
        if state == .recording { _ = microphone.stop() }
        state = .unavailable
    }

    /// A level reading from the Microphone while recording. Each reading also counts as time passing.
    public func microphoneLevel(_ level: Float) async {
        guard state == .recording else { return }
        self.level = level
        silentSince = level < Self.silenceThreshold ? silentSince ?? now() : nil
        await tick()
    }

    /// Time passing: the app calls this on a timer while recording, so the automatic stops still
    /// happen when the Microphone stalls and sends no readings.
    public func tick() async {
        guard state == .recording, let startedAt else { return }
        let now = now()
        let silentTooLong = silentSince.map { now - $0 >= Self.silenceLimit } ?? false
        if silentTooLong || now - startedAt >= Self.lengthLimit { await stop() }
    }

    /// Every stop, manual or automatic, goes through here: drop an accidental tap, otherwise
    /// transcribe the Recording and insert a non-empty Transcript.
    private func stop() async {
        let recording = microphone.stop()
        guard let startedAt, now() - startedAt >= Self.minimumRecording else {
            state = .idle
            return
        }
        state = .transcribing
        defer { if state == .transcribing { state = .idle } }
        guard let transcript = try? await transcriber.transcribe(recording) else {
            return raise(.error("Couldn't transcribe"))
        }
        guard !transcript.allSatisfy(\.isWhitespace) else { return }
        lastTranscript = transcript
        do { try inserter.insert(transcript) } catch { raise(.error("Paste failed, Transcript copied")) }
    }

    /// Esc was pressed: cancel a recording Dictation, throwing its Recording away.
    public func escPressed() {
        guard state == .recording else { return }
        _ = microphone.stop()
        state = .idle
    }

    private func raise(_ kind: Signal.Kind) {
        signal = Signal(kind: kind, raised: now())
    }
}
