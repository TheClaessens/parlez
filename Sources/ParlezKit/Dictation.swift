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

    public private(set) var state: State = .idle {
        didSet {
            let recording = state == .recording
            if recording != (oldValue == .recording) { onRecordingChanged?(recording) }
        }
    }
    /// Called with true when a Dictation starts recording and false when it leaves recording, however it ends.
    /// The app registers Esc as a global hotkey only in between.
    @ObservationIgnored public var onRecordingChanged: (@MainActor (Bool) -> Void)?
    /// Kept for "Copy last Transcript".
    public private(set) var lastTranscript: String?

    private let microphone: any Microphone
    private let transcriber: any Transcriber
    private let inserter: any Inserter
    /// The Clock adapter. Nothing reads it yet; the 0.3 s minimum, silence and 10-minute rules will.
    private let now: @MainActor () -> ContinuousClock.Instant

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
            state = .recording
        case .recording:
            state = .transcribing
            let recording = microphone.stop()
            if let transcript = try? await transcriber.transcribe(recording) {
                lastTranscript = transcript
                inserter.insert(transcript)
            }
            state = .idle
        case .transcribing:
            break
        }
    }

    /// Esc was pressed: cancel a recording Dictation, throwing its Recording away.
    public func escPressed() {
        guard state == .recording else { return }
        _ = microphone.stop()
        state = .idle
    }
}
