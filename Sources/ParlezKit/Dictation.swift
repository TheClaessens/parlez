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

/// Applies the speaker's self-corrections to a Transcript (Retouche).
@MainActor public protocol Retoucher: AnyObject {
    /// Why Retouche can't run on this Mac, for Settings; nil when it can.
    var unavailableReason: String? { get }
    /// Gets the model ready, so the next `retouch` doesn't pay for loading it.
    func warmUp()
    /// Returns the Retouched Transcript. Throws when the model fails or the Transcript is too long for it.
    func retouch(_ transcript: String) async throws -> String
}

extension Retoucher {
    public var isAvailable: Bool { unavailableReason == nil }
}

/// The Dictation core: every rule about when a Dictation starts, stops and what gets inserted.
/// It makes no OS calls of its own; it only talks to the adapters it is given.
@MainActor @Observable
public final class Dictation {
    /// `unavailable` while Setup is not complete.
    public enum State: Equatable, Sendable { case unavailable, idle, recording, transcribing, retouching }

    /// A short-lived signal for the Island. Each one raised is a new value (its `raised` instant differs),
    /// so the Island can react to every raise and decide how long to show it.
    public struct Signal: Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            case busy, setupUnfinished, pasted(words: Int, retouche: Retouche = .notAttempted), cancelled, nothingHeard, error(Reason)
        }
        /// How Retouche went for a paste: skipped means it fell back to the Transcript.
        public enum Retouche: Equatable, Sendable { case notAttempted, applied, skipped }
        /// What went wrong; the Island owns the wording.
        public enum Reason: Equatable, Sendable { case microphoneDidNotStart, couldNotTranscribe, pasteFailed }
        public let kind: Kind
        public let raised: ContinuousClock.Instant
    }

    /// When a recording Dictation will stop by itself, and why.
    public struct AutomaticStop: Equatable, Sendable {
        public enum Reason: Equatable, Sendable { case silence, lengthLimit }
        public let at: ContinuousClock.Instant
        public let reason: Reason
        public init(at: ContinuousClock.Instant, reason: Reason) {
            self.at = at
            self.reason = reason
        }
    }

    public private(set) var state: State = .unavailable {
        didSet {
            let recording = state == .recording
            guard recording != (oldValue == .recording) else { return }
            // However a recording ends (stop, automatic stop, Esc), drop its silence/length tracking.
            if !recording { silentSince = nil; recordingStartedAt = nil; level = 0 }
            onRecordingChanged?(recording)
        }
    }
    /// The latest Microphone level while recording (for the Island's waveform); 0 otherwise.
    public private(set) var level: Float = 0
    /// When the current Recording started (for the Island's elapsed time); nil while not recording.
    public private(set) var recordingStartedAt: ContinuousClock.Instant?
    /// The earliest pending automatic stop while recording; nil otherwise.
    public var automaticStop: AutomaticStop? {
        guard state == .recording, let recordingStartedAt else { return nil }
        let lengthStop = AutomaticStop(at: recordingStartedAt + Self.lengthLimit, reason: .lengthLimit)
        guard let silentSince, silentSince + Self.silenceLimit < lengthStop.at else { return lengthStop }
        return AutomaticStop(at: silentSince + Self.silenceLimit, reason: .silence)
    }
    /// Called with true when a Dictation starts recording and false when it leaves recording, however it ends.
    /// The app registers Esc as the cancel shortcut only in between.
    @ObservationIgnored public var onRecordingChanged: (@MainActor (Bool) -> Void)?
    /// The last signal raised; cleared when the next Dictation starts.
    public private(set) var signal: Signal?
    /// Kept for "Copy last Transcript": what was inserted, the Retouched Transcript when Retouche ran.
    public private(set) var lastTranscript: String?

    /// Which stops are retouched. The app sets it from Settings.
    public enum RetoucheSetting: Equatable, Sendable { case off, onDictationShortcut, onOwnShortcut }
    @ObservationIgnored public var retouche: RetoucheSetting = .off

    /// A Recording shorter than this is an accidental tap and is thrown away.
    public static let minimumRecording: Duration = .milliseconds(300)

    private let microphone: any Microphone
    private let transcriber: any Transcriber
    private let inserter: any Inserter
    private let retoucher: any Retoucher
    /// Reads the current instant (injected so tests control time), for the silence and length limits
    /// and the 0.3 s minimum.
    private let now: @MainActor () -> ContinuousClock.Instant
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
        retoucher: any Retoucher,
        now: @escaping @MainActor () -> ContinuousClock.Instant = { .now }
    ) {
        self.microphone = microphone
        self.transcriber = transcriber
        self.inserter = inserter
        self.retoucher = retoucher
        self.now = now
    }

    /// The Dictation shortcut was pressed: start a Dictation, or stop it and insert its Transcript.
    public func shortcutPressed() async {
        switch state {
        case .idle:
            guard (try? microphone.start()) != nil else { return raise(.error(.microphoneDidNotStart)) }
            recordingStartedAt = now()
            signal = nil
            state = .recording
            if retouche != .off, retoucher.isAvailable { retoucher.warmUp() }
        case .recording:
            await stop()
        case .unavailable:
            raise(.setupUnfinished)
        case .transcribing, .retouching:
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
        if let automaticStop, now() >= automaticStop.at { await stop() }
    }

    /// Every stop, manual or automatic, goes through here: drop an accidental tap, otherwise
    /// transcribe the Recording and insert a non-empty Transcript.
    private func stop() async {
        let recording = microphone.stop()
        guard let recordingStartedAt, now() - recordingStartedAt >= Self.minimumRecording else {
            state = .idle
            return
        }
        state = .transcribing
        defer { if state == .transcribing || state == .retouching { state = .idle } }
        guard var transcript = try? await transcriber.transcribe(recording) else {
            return raise(.error(.couldNotTranscribe))
        }
        var outcome = Signal.Retouche.notAttempted
        if retouche == .onDictationShortcut, retoucher.isAvailable {
            if state == .transcribing { state = .retouching }
            outcome = .skipped
            if let retouched = try? await retoucher.retouch(transcript), Self.canTrust(retouched, from: transcript) {
                transcript = retouched
                outcome = .applied
            }
        }
        guard !transcript.allSatisfy(\.isWhitespace) else { return raise(.nothingHeard) }
        lastTranscript = transcript
        do {
            try inserter.insert(transcript)
            raise(.pasted(words: transcript.split(whereSeparator: \.isWhitespace).count, retouche: outcome))
        } catch { raise(.error(.pasteFailed)) }
    }

    /// The fallback rule (from the prototype): a Retouche only deletes, so a Retouched Transcript that adds
    /// line breaks, or whose words are less than 90 % from the Transcript, ran away (an email, an answer,
    /// a translation) and the Transcript is inserted instead. An empty one is trusted: everything was filler.
    private static func canTrust(_ retouched: String, from transcript: String) -> Bool {
        let lineBreaks = { (text: String) in text.filter(\.isNewline).count }
        let words = { (text: String) in text.lowercased().split { !$0.isLetter && !$0.isNumber && $0 != "'" } }
        let spoken = Set(words(transcript))
        let out = words(retouched)
        return lineBreaks(retouched) <= lineBreaks(transcript)
            && Double(out.filter(spoken.contains).count) >= 0.9 * Double(out.count)
    }

    /// Esc was pressed: cancel a recording Dictation, throwing its Recording away.
    public func escPressed() {
        guard state == .recording else { return }
        _ = microphone.stop()
        state = .idle
        raise(.cancelled)
    }

    private func raise(_ kind: Signal.Kind) {
        signal = Signal(kind: kind, raised: now())
    }
}
