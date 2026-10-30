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
    func insert(_ transcript: String)
}

/// The Dictation core: every rule about when a Dictation starts, stops and what gets inserted.
/// It makes no OS calls of its own; it only talks to the adapters it is given.
@MainActor @Observable
public final class Dictation {
    public enum State: Equatable, Sendable { case idle, recording, transcribing }

    public private(set) var state: State = .idle
    /// The latest Microphone level while recording (for the Island's meter); 0 otherwise.
    public private(set) var level: Float = 0
    /// Kept for "Copy last Transcript".
    public private(set) var lastTranscript: String?

    private let microphone: any Microphone
    private let transcriber: any Transcriber
    private let inserter: any Inserter
    /// The Clock adapter, for the silence and length limits (and the 0.3 s minimum).
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
            guard (try? microphone.start()) != nil else { return }
            startedAt = now()
            state = .recording
        case .recording:
            await stop()
        case .transcribing:
            break
        }
    }

    /// A level reading from the Microphone while recording. Readings are also the core's sense of
    /// time passing: the automatic stops are judged on each one.
    public func microphoneLevel(_ level: Float) async {
        guard state == .recording, let startedAt else { return }
        self.level = level
        let now = now()
        silentSince = level < Self.silenceThreshold ? silentSince ?? now : nil
        let silentTooLong = silentSince.map { now - $0 >= Self.silenceLimit } ?? false
        if silentTooLong || now - startedAt >= Self.lengthLimit { await stop() }
    }

    /// Every stop, manual or automatic, goes through here: transcribe the Recording and insert it.
    private func stop() async {
        state = .transcribing
        silentSince = nil
        startedAt = nil
        level = 0
        let recording = microphone.stop()
        if let transcript = try? await transcriber.transcribe(recording) {
            lastTranscript = transcript
            inserter.insert(transcript)
        }
        state = .idle
    }
}
