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

    /// A short-lived signal for the Island. Each one raised is a new value (its `raised` instant differs),
    /// so the Island can react to every raise and decide how long to show it.
    public struct Signal: Equatable, Sendable {
        public enum Kind: Equatable, Sendable { case busy, error(String) }
        public let kind: Kind
        public let raised: ContinuousClock.Instant
    }

    public private(set) var state: State = .idle
    /// The last signal raised; cleared when the next Dictation starts.
    public private(set) var signal: Signal?
    /// Kept for "Copy last Transcript".
    public private(set) var lastTranscript: String?

    /// A Recording shorter than this is an accidental tap and is thrown away.
    public static let minimumRecording: Duration = .milliseconds(300)

    private let microphone: any Microphone
    private let transcriber: any Transcriber
    private let inserter: any Inserter
    /// The Clock adapter.
    private let now: @MainActor () -> ContinuousClock.Instant
    private var recordingStarted = ContinuousClock.now

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
            recordingStarted = now()
            signal = nil
            state = .recording
        case .recording:
            let recording = microphone.stop()
            if now() - recordingStarted < Self.minimumRecording {
                state = .idle
                return
            }
            state = .transcribing
            do {
                let transcript = try await transcriber.transcribe(recording)
                if !transcript.allSatisfy(\.isWhitespace) {
                    lastTranscript = transcript
                    inserter.insert(transcript)
                }
            } catch {
                raise(.error("Transcription failed"))
            }
            state = .idle
        case .transcribing:
            raise(.busy)
        }
    }

    private func raise(_ kind: Signal.Kind) {
        signal = Signal(kind: kind, raised: now())
    }
}
