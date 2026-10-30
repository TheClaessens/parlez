import ParlezKit
import Testing

@MainActor @Suite(.timeLimit(.minutes(1)))
struct DictationTests {
    let microphone = FakeMicrophone()
    let transcriber = FakeTranscriber()
    let inserter = FakeInserter()
    let retoucher = FakeRetoucher()
    let clock = FakeClock()
    let dictation: Dictation

    init() {
        dictation = Dictation(
            microphone: microphone, transcriber: transcriber, inserter: inserter, retoucher: retoucher,
            now: { [clock] in clock.now })
        dictation.setupCompleted()
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

    // MARK: Setup

    @Test func beforeSetupIsCompleteThePressStartsNothingAndSignalsSetupUnfinished() async {
        let dictation = Dictation(
            microphone: microphone, transcriber: transcriber, inserter: inserter, retoucher: retoucher,
            now: { [clock] in clock.now })
        #expect(dictation.state == .unavailable)

        await dictation.shortcutPressed()

        #expect(dictation.state == .unavailable)
        #expect(dictation.signal?.kind == .setupUnfinished)

        dictation.setupCompleted()
        #expect(dictation.state == .idle)
        await dictation.shortcutPressed()
        #expect(dictation.state == .recording)
    }

    @Test func setupIncompleteMakesTheShortcutUnavailableAgain() async {
        dictation.setupIncomplete()

        await dictation.shortcutPressed()

        #expect(dictation.state == .unavailable)
        #expect(dictation.signal?.kind == .setupUnfinished)
        #expect(transcriber.calls == 0)
    }

    @Test func setupIncompleteWhileRecordingThrowsTheRecordingAway() async {
        await dictation.shortcutPressed()
        clock.now += .seconds(1)

        dictation.setupIncomplete()

        #expect(dictation.state == .unavailable)
        #expect(microphone.stops == 1)
        #expect(transcriber.calls == 0)
        #expect(dictation.signal == nil)
    }

    @Test func setupIncompleteWhileTranscribingStillInsertsThenStaysUnavailable() async {
        await dictation.shortcutPressed()
        clock.now += .seconds(1)
        transcriber.holds = true
        let stop = Task { await dictation.shortcutPressed() }
        await transcriber.started()

        dictation.setupIncomplete()
        transcriber.finish("Nog net.")
        await stop.value

        #expect(inserter.inserted == ["Nog net."])
        #expect(dictation.state == .unavailable)
    }

    @Test func transcriptIsInsertedAtTheCaret() async {
        transcriber.transcript = "Ik denk hardop."

        await dictate()

        #expect(inserter.inserted == ["Ik denk hardop."])
    }

    @Test func pastingSignalsPastedWithTheWordCount() async {
        transcriber.transcript = " Ik denk\nhardop,  echt. "

        await dictate()

        #expect(dictation.signal?.kind == .pasted(words: 4))
    }

    @Test func lastTranscriptIsKept() async {
        #expect(dictation.lastTranscript == nil)

        transcriber.transcript = "First."
        await dictate()
        transcriber.transcript = "Second."
        await dictate()

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

        clock.now += .seconds(1)
        await dictation.shortcutPressed()
        #expect(dictation.level == 0)
    }

    @Test func recordingStartedAtIsSetWhileRecordingOnly() async {
        #expect(dictation.recordingStartedAt == nil)

        let start = clock.now
        await dictation.shortcutPressed()
        clock.now += .seconds(1)
        await dictation.microphoneLevel(speech)
        #expect(dictation.recordingStartedAt == start)

        transcriber.holds = true
        let stop = Task { await dictation.shortcutPressed() }
        await transcriber.started()
        #expect(dictation.recordingStartedAt == nil)

        transcriber.finish("Klaar.")
        await stop.value
        await dictation.shortcutPressed()
        dictation.escPressed()
        #expect(dictation.recordingStartedAt == nil)
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

    @Test func automaticStopWithAnEmptyTranscriptInsertsNothing() async {
        transcriber.transcript = " "
        await dictation.shortcutPressed()
        await dictation.microphoneLevel(quiet)
        clock.now += Dictation.silenceLimit
        await dictation.microphoneLevel(quiet)

        #expect(dictation.state == .idle)
        #expect(transcriber.calls == 1)
        #expect(inserter.inserted.isEmpty)
        #expect(dictation.lastTranscript == nil)
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

    @Test func stalledMicrophoneStillStopsAtTenMinutes() async {
        transcriber.transcript = "Stil gevallen."
        await dictation.shortcutPressed()

        clock.now += .seconds(599)
        await dictation.tick()
        #expect(dictation.state == .recording)

        clock.now += .seconds(1)
        await dictation.tick()

        #expect(dictation.state == .idle)
        #expect(inserter.inserted == ["Stil gevallen."])
    }

    @Test func silenceStopsOnTicksAfterTheReadingsStop() async {
        await dictation.shortcutPressed()
        await dictation.microphoneLevel(quiet)

        clock.now += Dictation.silenceLimit
        await dictation.tick()

        #expect(dictation.state == .idle)
        #expect(inserter.inserted.count == 1)
    }

    @Test func automaticStopIsTheLengthLimitWhileThereIsSound() async {
        let start = clock.now
        await dictation.shortcutPressed()
        clock.now += .seconds(5)
        await dictation.microphoneLevel(speech)

        #expect(dictation.automaticStop == .init(at: start + .seconds(600), reason: .lengthLimit))
    }

    @Test func automaticStopSwitchesToTheSilenceStopWhileSilentAndBackWhenSoundReturns() async {
        let start = clock.now
        await dictation.shortcutPressed()
        clock.now += .seconds(5)
        await dictation.microphoneLevel(quiet)
        clock.now += .seconds(10)
        await dictation.microphoneLevel(quiet)

        #expect(dictation.automaticStop == .init(at: start + .seconds(35), reason: .silence))

        await dictation.microphoneLevel(speech)

        #expect(dictation.automaticStop == .init(at: start + .seconds(600), reason: .lengthLimit))
    }

    @Test func automaticStopIsNilOutsideRecording() async {
        #expect(dictation.automaticStop == nil)

        await dictation.shortcutPressed()
        clock.now += .seconds(1)
        transcriber.holds = true
        let stop = Task { await dictation.shortcutPressed() }
        await transcriber.started()
        #expect(dictation.automaticStop == nil)

        transcriber.finish("Klaar.")
        await stop.value
        #expect(dictation.automaticStop == nil)
    }

    @Test(arguments: [true, false])
    func theAutomaticStopHappensAtTheInstantItReported(silent: Bool) async {
        await dictation.shortcutPressed()
        await dictation.microphoneLevel(silent ? quiet : speech)
        let reported = dictation.automaticStop
        #expect(reported?.reason == (silent ? .silence : .lengthLimit))

        clock.now = reported!.at - .milliseconds(1)
        await dictation.tick()
        #expect(dictation.state == .recording)

        clock.now = reported!.at
        await dictation.tick()
        #expect(dictation.state == .idle)
        #expect(inserter.inserted.count == 1)
    }

    // MARK: Esc
    @Test func escWhileRecordingCancelsWithNothingTranscribedOrInserted() async {
        await dictation.shortcutPressed()

        dictation.escPressed()

        #expect(dictation.state == .idle)
        #expect(microphone.stops == 1)
        #expect(transcriber.calls == 0)
        #expect(inserter.inserted.isEmpty)
        #expect(dictation.lastTranscript == nil)
        #expect(dictation.signal?.kind == .cancelled)
    }

    @Test func escWhileIdleChangesNothing() {
        dictation.escPressed()

        #expect(dictation.state == .idle)
        #expect(microphone.stops == 0)
    }

    @Test func escWhileTranscribingChangesNothing() async {
        await dictation.shortcutPressed()
        clock.now += .seconds(1)
        transcriber.holds = true
        let stop = Task { await dictation.shortcutPressed() }
        await transcriber.started()

        dictation.escPressed()
        #expect(dictation.state == .transcribing)
        #expect(dictation.signal == nil)

        transcriber.finish("Still inserted.")
        await stop.value
        #expect(inserter.inserted == ["Still inserted."])
        #expect(microphone.stops == 1)
    }

    @Test func reportsEnteringAndLeavingRecordingHoweverItEnds() async {
        var reports: [Bool] = []
        dictation.onRecordingChanged = { reports.append($0) }

        await dictation.shortcutPressed()
        dictation.escPressed()
        await dictation.shortcutPressed()
        clock.now += .seconds(1)
        await dictation.shortcutPressed()

        #expect(inserter.inserted.count == 1)
        #expect(reports == [true, false, true, false])
    }

    @Test func automaticStopReportsLeavingRecordingSoEscIsDisabled() async {
        var reports: [Bool] = []
        dictation.onRecordingChanged = { reports.append($0) }

        await dictation.shortcutPressed()
        await dictation.microphoneLevel(quiet)
        clock.now += Dictation.silenceLimit
        await dictation.microphoneLevel(quiet)

        #expect(dictation.state == .idle)
        #expect(reports == [true, false])
    }

    @Test func escCancelThenNewDictationStartsWithFreshSilenceTracking() async {
        await dictation.shortcutPressed()
        await dictation.microphoneLevel(quiet)
        clock.now += .seconds(20)
        dictation.escPressed()
        #expect(dictation.level == 0)

        await dictation.shortcutPressed()
        await dictation.microphoneLevel(quiet)
        clock.now += .seconds(10)
        await dictation.microphoneLevel(quiet)

        #expect(dictation.state == .recording)
        #expect(inserter.inserted.isEmpty)
    }

    // MARK: Edge rules

    @Test func recordingUnderPointThreeSecondsIsThrownAway() async {
        await dictation.shortcutPressed()
        clock.now += .milliseconds(290)
        await dictation.shortcutPressed()

        #expect(transcriber.calls == 0)
        #expect(inserter.inserted.isEmpty)
        #expect(dictation.state == .idle)
        #expect(dictation.signal == nil)
    }

    @Test func microphoneThatFailsToStartSignalsAnError() async {
        microphone.fails = true

        await dictation.shortcutPressed()

        #expect(dictation.state == .idle)
        #expect(dictation.signal?.kind == .error(.microphoneDidNotStart))
    }

    @Test func emptyTranscriptInsertsNothing() async {
        transcriber.transcript = "Kept."
        await dictate()
        transcriber.transcript = " "
        await dictate()

        #expect(inserter.inserted == ["Kept."])
        #expect(dictation.lastTranscript == "Kept.")
        #expect(dictation.state == .idle)
        #expect(dictation.signal?.kind == .nothingHeard)
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

    @Test func failingToTranscribeSignalsAnErrorAndInsertsNothing() async {
        transcriber.fails = true

        await dictate()

        #expect(dictation.signal?.kind == .error(.couldNotTranscribe))
        #expect(inserter.inserted.isEmpty)
        #expect(dictation.lastTranscript == nil)
        #expect(dictation.state == .idle)
    }

    @Test func failedPasteSignalsAnErrorAndKeepsTheTranscript() async {
        transcriber.transcript = "Niet geplakt."
        inserter.fails = true

        await dictate()

        #expect(dictation.signal?.kind == .error(.pasteFailed))
        #expect(dictation.lastTranscript == "Niet geplakt.")
        #expect(dictation.state == .idle)
    }

    @Test func startingADictationClearsTheSignal() async {
        transcriber.fails = true
        await dictate()
        #expect(dictation.signal != nil)

        await dictation.shortcutPressed()

        #expect(dictation.signal == nil)
    }

    // MARK: Retouche

    /// The prototype's first case: a self-correction.
    let corrected = "The button should be red. Oh wait, actually the button should be green."

    @Test func onTheDictationShortcutAGoodRetouchedTranscriptIsInsertedCountedAndKept() async {
        dictation.retouche = .onDictationShortcut
        transcriber.transcript = corrected
        retoucher.retouched = "The button should be green."

        await dictate()

        #expect(retoucher.calls == [corrected])
        #expect(inserter.inserted == ["The button should be green."])
        #expect(dictation.signal?.kind == .pasted(words: 5, retouche: .applied))
        #expect(dictation.lastTranscript == "The button should be green.")
    }

    @Test func automaticStopIsRetouchedOnTheDictationShortcut() async {
        dictation.retouche = .onDictationShortcut
        transcriber.transcript = corrected
        retoucher.retouched = "The button should be green."
        await dictation.shortcutPressed()
        await dictation.microphoneLevel(quiet)
        clock.now += Dictation.silenceLimit
        await dictation.microphoneLevel(quiet)

        #expect(inserter.inserted == ["The button should be green."])
    }

    @Test(arguments: [Dictation.RetoucheSetting.off, .onOwnShortcut])
    func theDictationShortcutInsertsTheTranscriptUnlessRetoucheIsOnIt(setting: Dictation.RetoucheSetting) async {
        dictation.retouche = setting
        transcriber.transcript = corrected
        retoucher.retouched = "The button should be green."

        await dictate()

        #expect(retoucher.calls.isEmpty)
        #expect(inserter.inserted == [corrected])
        #expect(dictation.signal?.kind == .pasted(words: 13, retouche: .notAttempted))
    }

    /// With Retouche on its own shortcut, the shortcut that stops decides, whichever one started.
    @Test(arguments: [
        (Dictation.Shortcut.dictation, Dictation.Shortcut.retouche, true),
        (.retouche, .retouche, true),
        (.retouche, .dictation, false),
        (.dictation, .dictation, false),
    ])
    func onItsOwnShortcutTheStoppingShortcutDecides(start: Dictation.Shortcut, stop: Dictation.Shortcut, retouches: Bool) async {
        dictation.retouche = .onOwnShortcut
        transcriber.transcript = corrected
        retoucher.retouched = "The button should be green."

        await dictation.shortcutPressed(start)
        clock.now += .seconds(1)
        await dictation.shortcutPressed(stop)

        #expect(inserter.inserted == [retouches ? "The button should be green." : corrected])
        #expect(dictation.lastTranscript == (retouches ? "The button should be green." : corrected))
        #expect(dictation.signal?.kind == (retouches ? .pasted(words: 5, retouche: .applied) : .pasted(words: 13, retouche: .notAttempted)))
    }

    /// Setting off, or Retouche unavailable: the Retouche shortcut is a plain Dictation shortcut.
    @Test(arguments: [(Dictation.RetoucheSetting.off, nil), (.onOwnShortcut, "Needs macOS 26.")])
    func theRetoucheShortcutIsAPlainDictationShortcutWhenRetoucheCantRun(setting: Dictation.RetoucheSetting, unavailable: String?) async {
        dictation.retouche = setting
        retoucher.unavailableReason = unavailable
        transcriber.transcript = corrected
        retoucher.retouched = "The button should be green."

        await dictation.shortcutPressed(.retouche)
        #expect(dictation.state == .recording)
        clock.now += .seconds(1)
        await dictation.shortcutPressed(.retouche)

        #expect(retoucher.calls.isEmpty)
        #expect(inserter.inserted == [corrected])
        #expect(dictation.signal?.kind == .pasted(words: 13, retouche: .notAttempted))
    }

    @Test func automaticStopIsNotRetouchedWhenRetoucheHasItsOwnShortcut() async {
        dictation.retouche = .onOwnShortcut
        transcriber.transcript = corrected
        retoucher.retouched = "The button should be green."
        await dictation.shortcutPressed()
        clock.now += Dictation.lengthLimit
        await dictation.tick()

        #expect(retoucher.calls.isEmpty)
        #expect(inserter.inserted == [corrected])
    }

    @Test func anUnavailableRetoucherRetouchesNothingAndIsNotWarmedUp() async {
        dictation.retouche = .onDictationShortcut
        retoucher.unavailableReason = "Needs macOS 26."
        transcriber.transcript = corrected
        retoucher.retouched = "The button should be green."

        await dictate()

        #expect(retoucher.calls.isEmpty)
        #expect(retoucher.warmUps == 0)
        #expect(inserter.inserted == [corrected])
    }

    /// Runaway outputs from the prototype (`prototype/edit-spike`, RESULTS.md): an email, an answer, a translation.
    @Test(arguments: [
        ("Write an email to Sam saying the release is delayed until Friday.",
         "Subject: Release delayed\n\nHi Sam,\n\nThe release is delayed until Friday.\n\nBest regards"),
        ("What's the capital of France?", "Paris"),
        ("De knop moet rood zijn. Oh nee wacht, de knop moet groen zijn.", "The button should be green."),
    ])
    func aRetouchedTranscriptThatAddsWordsOrLineBreaksFallsBackToTheTranscript(transcript: String, retouched: String) async {
        dictation.retouche = .onDictationShortcut
        transcriber.transcript = transcript
        retoucher.retouched = retouched

        await dictate()

        #expect(inserter.inserted == [transcript])
        #expect(dictation.lastTranscript == transcript)
        guard case .pasted(_, .skipped) = dictation.signal?.kind else {
            Issue.record("expected a paste with Retouche skipped, got \(String(describing: dictation.signal?.kind))")
            return
        }
    }

    @Test func dutchSelfCorrectionPassesTheFallbackRule() async {
        dictation.retouche = .onDictationShortcut
        transcriber.transcript = "We spreken af om drie uur, nee, om vier uur bij het station."
        retoucher.retouched = "We spreken af om vier uur bij het station."

        await dictate()

        #expect(inserter.inserted == ["We spreken af om vier uur bij het station."])
    }

    @Test func aThrowingRetoucherInsertsTheTranscript() async {
        dictation.retouche = .onDictationShortcut
        transcriber.transcript = corrected
        retoucher.fails = true

        await dictate()

        #expect(retoucher.calls == [corrected])
        #expect(inserter.inserted == [corrected])
        #expect(dictation.lastTranscript == corrected)
        #expect(dictation.signal?.kind == .pasted(words: 13, retouche: .skipped))
    }

    @Test func anEmptyRetouchedTranscriptInsertsNothingAndSignalsNothingHeard() async {
        dictation.retouche = .onDictationShortcut
        transcriber.transcript = "Um, uh."
        retoucher.retouched = " "

        await dictate()

        #expect(inserter.inserted.isEmpty)
        #expect(dictation.lastTranscript == nil)
        #expect(dictation.signal?.kind == .nothingHeard)
    }

    @Test func pressWhileRetouchingSignalsBusyAndStillInserts() async {
        dictation.retouche = .onDictationShortcut
        transcriber.transcript = corrected
        retoucher.holds = true
        await dictation.shortcutPressed()
        clock.now += .seconds(1)
        let stop = Task { await dictation.shortcutPressed() }
        await retoucher.started()

        await dictation.shortcutPressed()
        #expect(dictation.signal?.kind == .busy)
        #expect(microphone.stops == 1)

        retoucher.finish("The button should be green.")
        await stop.value
        #expect(inserter.inserted == ["The button should be green."])
        #expect(dictation.state == .idle)
    }

    /// A stop the retouch rule applies to shows as retouching straight away, through transcription and Retouche;
    /// any other stop shows as transcribing.
    @Test(arguments: [
        (Dictation.RetoucheSetting.onDictationShortcut, Dictation.Shortcut.dictation, Dictation.State.retouching),
        (.onOwnShortcut, .retouche, .retouching),
        (.onOwnShortcut, .dictation, .transcribing),
        (.off, .dictation, .transcribing),
    ])
    func aRetouchedStopIsRetouchingFromTheStart(setting: Dictation.RetoucheSetting, stop: Dictation.Shortcut, working: Dictation.State) async {
        dictation.retouche = setting
        transcriber.holds = true
        retoucher.holds = true
        await dictation.shortcutPressed()
        clock.now += .seconds(1)
        let stopping = Task { await dictation.shortcutPressed(stop) }
        await transcriber.started()
        #expect(dictation.state == working)

        transcriber.finish(corrected)
        if working == .retouching {
            await retoucher.started()
            #expect(dictation.state == .retouching)
            retoucher.finish("The button should be green.")
        }
        await stopping.value
        #expect(dictation.state == .idle)
    }

    @Test func escNeverRetouches() async {
        dictation.retouche = .onDictationShortcut
        await dictation.shortcutPressed()
        clock.now += .seconds(1)

        dictation.escPressed()

        #expect(retoucher.calls.isEmpty)
        #expect(inserter.inserted.isEmpty)
    }

    @Test(arguments: [
        (Dictation.RetoucheSetting.off, 0), (.onDictationShortcut, 1), (.onOwnShortcut, 1),
    ])
    func startingADictationWarmsUpTheRetoucherUnlessRetoucheIsOff(setting: Dictation.RetoucheSetting, warmUps: Int) async {
        dictation.retouche = setting

        await dictation.shortcutPressed()

        #expect(retoucher.warmUps == warmUps)
    }
}

// MARK: - Fake adapters

@MainActor final class FakeMicrophone: Microphone {
    var recording = Recording(samples: [0.1, -0.1], sampleRate: 48_000)
    /// When true, `start` throws.
    var fails = false
    func start() throws { if fails { throw MicrophoneFailed() } }
    private(set) var stops = 0
    func stop() -> Recording { stops += 1; return recording }
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
        if fails { throw TranscriberFailed() }
        guard holds else { return transcript }
        return await withCheckedContinuation { pending = $0; called.yield() }
    }

    /// Waits until a held `transcribe` call has started.
    func started() async { for await _ in started { return } }

    func finish(_ text: String) { pending?.resume(returning: text); pending = nil }
}

struct TranscriberFailed: Error {}
struct MicrophoneFailed: Error {}
struct InserterFailed: Error {}

@MainActor final class FakeInserter: Inserter {
    private(set) var inserted: [String] = []
    /// When true, `insert` throws, as the real one does without Accessibility permission.
    var fails = false
    func insert(_ transcript: String) throws {
        if fails { throw InserterFailed() }
        inserted.append(transcript)
    }
}

@MainActor final class FakeRetoucher: Retoucher {
    var unavailableReason: String?
    /// The Retouched Transcript returned when `holds` is false; nil returns the Transcript unchanged.
    var retouched: String?
    /// When true, `retouch` throws.
    var fails = false
    /// When true, `retouch` waits until the test calls `finish`.
    var holds = false
    /// The Transcripts it was asked to retouch.
    private(set) var calls: [String] = []
    private(set) var warmUps = 0
    private var pending: CheckedContinuation<String, Never>?
    private let (started, called) = AsyncStream<Void>.makeStream()

    func warmUp() { warmUps += 1 }

    func retouch(_ transcript: String) async throws -> String {
        calls.append(transcript)
        if fails { throw RetoucherFailed() }
        guard holds else { return retouched ?? transcript }
        return await withCheckedContinuation { pending = $0; called.yield() }
    }

    /// Waits until a held `retouch` call has started.
    func started() async { for await _ in started { return } }

    func finish(_ text: String) { pending?.resume(returning: text); pending = nil }
}

struct RetoucherFailed: Error {}

@MainActor final class FakeClock {
    var now = ContinuousClock.Instant.now
}
