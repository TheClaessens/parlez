import Foundation
import Observation
// `waitUntilLoaded` is SPI; it loads Uhm's model up front, so removing fillers never waits for a load.
@_spi(UhmBindings) import Uhm
import Voz

/// The Transcriber adapter: wraps Voz, and Uhm for Remove fillers (ADR 0003). Setup prepares Voz; until then it
/// has no model to transcribe with.
@MainActor @Observable public final class VozTranscriber: Transcriber {
    @ObservationIgnored private var voz: Voz?
    @ObservationIgnored private let uhm = Uhm()
    /// Remove fillers, set by the app from Settings. Takes effect once Uhm's model is loaded.
    @ObservationIgnored public var removesFillers = false
    /// Uhm's model download fraction while it is being prepared; nil otherwise.
    public private(set) var fillerModelProgress: Double?
    public private(set) var fillerModelLoaded = false
    public private(set) var fillerModelFailed = false

    public init() {}

    /// Whether Uhm's model is on disk, so launch can load it without a download.
    public var isFillerModelDownloaded: Bool { uhm.isDownloaded() }

    /// Downloads Uhm's model if it is missing (about 45 MB), then loads it. A no-op while it loads or once loaded.
    public func prepareFillerModel() async {
        guard !fillerModelLoaded, fillerModelProgress == nil else { return }
        fillerModelFailed = false
        fillerModelProgress = 0
        do {
            try await uhm.download { fraction in
                Task { @MainActor in if self.fillerModelProgress != nil { self.fillerModelProgress = fraction } }
            }
            try await uhm.waitUntilLoaded()
            fillerModelLoaded = true
        } catch {
            NSLog("Parlez: preparing the filler model failed: \(error)")
            fillerModelFailed = true
        }
        fillerModelProgress = nil
    }

    /// Whether the model is on disk, so Setup knows whether its model step needs a download.
    public static var isModelDownloaded: Bool { Voz.isDownloaded() }

    /// Downloads the model if it is missing (reporting the fraction done), then loads it once
    /// so the first Dictation is fast: ~0.3 s from cache, ~20 s on the first load after a download.
    public func prepare(progress: @escaping @Sendable (Double) -> Void) async throws {
        voz = try await Voz(progress: { progress($0.fraction) })
    }

    public func transcribe(_ recording: Recording) async throws -> String {
        guard let voz else { throw NotPrepared() }
        let samples = recording.samples, sampleRate = recording.sampleRate
        guard removesFillers, fillerModelLoaded else {
            return try await voz.transcribe(samples: samples, sampleRate: sampleRate).text
        }
        // Precision is the SDK's bias for automatic cuts; the type labels are unreliable and cost time.
        async let analysis = uhm.analyze(
            samples: samples, sampleRate: Int(sampleRate), options: .init(bias: .precision, includeTypes: false))
        let result = try await voz.transcribe(samples: samples, sampleRate: sampleRate)
        do {
            return removeFillers(text: result.text, words: result.words, fillers: try await analysis.fillers)
        } catch {
            NSLog("Parlez: removing fillers failed, inserting Voz's Transcript: \(error)")
            return result.text
        }
    }

    private struct NotPrepared: Error {}
}

/// Removing fillers: the Transcript without the words Voz transcribed fully inside one of Uhm's filler spans
/// (the "word fully inside filler" rule of `Uhm.reconcileWords`). Voz's `text` unchanged when no word is dropped,
/// otherwise the surviving words joined with spaces; Voz's words carry their punctuation.
public func removeFillers(text: String, words: [Word], fillers: [Uhm.Detection]) -> String {
    // The index stands in for the word, so `reconcileWords` reports which ones survive.
    let ranges = words.indices.map { WordRange(start: words[$0].start, end: words[$0].end, word: String($0)) }
    let surviving = Set(Uhm.reconcileWords(ranges, fillers: fillers).compactMap { Int($0.word) })
    // `reconcileWords` also leaves out words without duration, which Voz gives the words it clamps to the end of
    // the Recording; they are kept.
    let kept = words.indices.filter { surviving.contains($0) || words[$0].duration <= 0 }
    if kept.count == words.count { return text }
    return kept.map { words[$0].text }.joined(separator: " ")
}
