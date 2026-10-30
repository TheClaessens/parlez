import ParlezKit
import Testing

@MainActor @Suite(.timeLimit(.minutes(1)))
struct DictationTests {
    let microphone = FakeMicrophone()
    let transcriber = FakeTranscriber()
    let inserter = FakeInserter()
    let clock = FakeClock()
    let dictation: Dictation

    init() {
        dictation = Dictation(
            microphone: microphone, transcriber: transcriber, inserter: inserter, now: { [clock] in clock.now })
    }

    /// One whole Dictation, long enough to be kept.
    func dictate() async {
        await dictation.shortcutPressed()
        clock.now += .seconds(1)
        await dictation.shortcutPressed()
    }

    @Test func shortcutTogglesIdleRecordingTranscribingIdle() async {
        #expect(dictation.state == .idle)

        await dictation.shortcutPressed()
        #expect(dictation.state == .recording)

        clock.now += .seconds(1)
        transcriber.holds = true
        let stop = Task { await dictation.shortcutPressed() }
        await transcriber.started()
        #expect(dictation.state == .transcribing)

        transcriber.finish("Hallo")
        await stop.value
        #expect(dictation.state == .idle)
    }

    @Test func transcriptIsInsertedAtTheCaret() async {
        transcriber.transcript = "Ik denk hardop."

        await dictate()

        #expect(inserter.inserted == ["Ik denk hardop."])
    }

    @Test func lastTranscriptIsKept() async {
        #expect(dictation.lastTranscript == nil)

        transcriber.transcript = "First."
        await dictate()
        transcriber.transcript = "Second."
        await dictate()

        #expect(dictation.lastTranscript == "Second.")
    }

    @Test func recordingUnderPointThreeSecondsIsThrownAway() async {
        await dictation.shortcutPressed()
        clock.now += .milliseconds(290)
        await dictation.shortcutPressed()

        #expect(transcriber.calls == 0)
        #expect(inserter.inserted.isEmpty)
        #expect(dictation.state == .idle)
    }

    @Test func emptyTranscriptInsertsNothing() async {
        transcriber.transcript = "Kept."
        await dictate()
        transcriber.transcript = " "
        await dictate()

        #expect(inserter.inserted == ["Kept."])
        #expect(dictation.lastTranscript == "Kept.")
        #expect(dictation.state == .idle)
    }

    @Test func pressWhileTranscribingIsIgnoredAndSignalsBusy() async {
        await dictation.shortcutPressed()
        clock.now += .seconds(1)
        transcriber.holds = true
        let stop = Task { await dictation.shortcutPressed() }
        await transcriber.started()
        #expect(dictation.signal == nil)

        await dictation.shortcutPressed()

        #expect(dictation.state == .transcribing)
        #expect(dictation.signal?.kind == .busy)
        #expect(transcriber.calls == 1)

        transcriber.finish("Done.")
        await stop.value
        #expect(inserter.inserted == ["Done."])
    }

    @Test func transcriptionFailureSignalsAnErrorAndInsertsNothing() async {
        transcriber.fails = true

        await dictate()

        #expect(dictation.signal?.kind == .error("Transcription failed"))
        #expect(inserter.inserted.isEmpty)
        #expect(dictation.lastTranscript == nil)
        #expect(dictation.state == .idle)
    }

    @Test func startingADictationClearsTheSignal() async {
        transcriber.fails = true
        await dictate()
        #expect(dictation.signal != nil)

        await dictation.shortcutPressed()

        #expect(dictation.signal == nil)
    }
}

// MARK: - Fake adapters

@MainActor final class FakeMicrophone: Microphone {
    var recording = Recording(samples: [0.1, -0.1], sampleRate: 48_000)
    func start() throws {}
    func stop() -> Recording { recording }
}

@MainActor final class FakeTranscriber: Transcriber {
    /// The Transcript returned straight away when `holds` is false.
    var transcript = "Hello world."
    /// When true, `transcribe` waits until the test calls `finish`.
    var holds = false
    /// When true, `transcribe` throws.
    var fails = false
    private(set) var calls = 0
    private var pending: CheckedContinuation<String, Never>?
    private let (started, called) = AsyncStream<Void>.makeStream()

    func transcribe(_ recording: Recording) async throws -> String {
        calls += 1
        if fails { throw TranscriptionFailed() }
        guard holds else { return transcript }
        return await withCheckedContinuation { pending = $0; called.yield() }
    }

    /// Waits until a held transcription has started.
    func started() async { for await _ in started { return } }

    func finish(_ text: String) { pending?.resume(returning: text); pending = nil }
}

struct TranscriptionFailed: Error {}

@MainActor final class FakeInserter: Inserter {
    private(set) var inserted: [String] = []
    func insert(_ transcript: String) { inserted.append(transcript) }
}

@MainActor final class FakeClock {
    var now = ContinuousClock.Instant.now
}
