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

    @Test func shortcutTogglesIdleRecordingTranscribingIdle() async {
        #expect(dictation.state == .idle)

        await dictation.shortcutPressed()
        #expect(dictation.state == .recording)

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

        await dictation.shortcutPressed()
        await dictation.shortcutPressed()

        #expect(inserter.inserted == ["Ik denk hardop."])
    }

    @Test func lastTranscriptIsKept() async {
        #expect(dictation.lastTranscript == nil)

        transcriber.transcript = "First."
        await dictation.shortcutPressed()
        await dictation.shortcutPressed()
        transcriber.transcript = "Second."
        await dictation.shortcutPressed()
        await dictation.shortcutPressed()

        #expect(dictation.lastTranscript == "Second.")
    }

    // MARK: Automatic stop

    let quiet: Float = Dictation.silenceThreshold / 2
    let speech: Float = Dictation.silenceThreshold * 10

    @Test func levelIsObservableWhileRecordingOnly() async {
        await dictation.microphoneLevel(0.4)
        #expect(dictation.level == 0)

        await dictation.shortcutPressed()
        await dictation.microphoneLevel(0.4)
        #expect(dictation.level == 0.4)

        await dictation.shortcutPressed()
        #expect(dictation.level == 0)
    }

    @Test func thirtySecondsOfSilenceStopsAndInserts() async {
        transcriber.transcript = "Vergeten."
        await dictation.shortcutPressed()

        await dictation.microphoneLevel(quiet)
        clock.now += .seconds(29)
        await dictation.microphoneLevel(quiet)
        #expect(dictation.state == .recording)

        clock.now += .seconds(1)
        await dictation.microphoneLevel(quiet)

        #expect(dictation.state == .idle)
        #expect(inserter.inserted == ["Vergeten."])
    }

    @Test func speechResetsTheSilenceCountdown() async {
        await dictation.shortcutPressed()

        await dictation.microphoneLevel(quiet)
        clock.now += .seconds(20)
        await dictation.microphoneLevel(speech)
        clock.now += .seconds(1)
        await dictation.microphoneLevel(quiet)
        clock.now += .seconds(29)
        await dictation.microphoneLevel(quiet)

        #expect(dictation.state == .recording)
        #expect(inserter.inserted.isEmpty)
    }

    @Test func tenMinutesStopsAndInsertsEvenWithoutSilence() async {
        transcriber.transcript = "Lawaaierig café."
        await dictation.shortcutPressed()

        clock.now += .seconds(599)
        await dictation.microphoneLevel(speech)
        #expect(dictation.state == .recording)

        clock.now += .seconds(1)
        await dictation.microphoneLevel(speech)

        #expect(dictation.state == .idle)
        #expect(inserter.inserted == ["Lawaaierig café."])
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
    private var pending: CheckedContinuation<String, Never>?
    private let (calls, called) = AsyncStream<Void>.makeStream()

    func transcribe(_ recording: Recording) async throws -> String {
        guard holds else { return transcript }
        return await withCheckedContinuation { pending = $0; called.yield() }
    }

    /// Waits until a held transcription has started.
    func started() async { for await _ in calls { return } }

    func finish(_ text: String) { pending?.resume(returning: text); pending = nil }
}

@MainActor final class FakeInserter: Inserter {
    private(set) var inserted: [String] = []
    func insert(_ transcript: String) { inserted.append(transcript) }
}

@MainActor final class FakeClock {
    var now = ContinuousClock.Instant.now
}
