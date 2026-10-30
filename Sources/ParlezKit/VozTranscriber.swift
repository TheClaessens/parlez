import Foundation
import Uhm
import Voz

/// The Transcriber adapter: wraps Voz, and Uhm for Remove fillers (ADR 0003). Setup prepares Voz, and the app
/// prepares Uhm while Remove fillers is on; until then each has no model to run.
@MainActor public final class VozTranscriber: Transcriber {
    private var voz: Voz?
    private let uhm = Uhm()
    /// Remove fillers; the app sets it once Uhm's model is prepared.
    public var removesFillers = false

    public init() {}

    /// Whether the model is on disk, so Setup knows whether its model step needs a download.
    public static var isModelDownloaded: Bool { Voz.isDownloaded() }

    /// Whether Uhm's model is on disk, so the app knows whether preparing it downloads.
    public static var isFillerModelDownloaded: Bool { Uhm.isDownloaded() }

    /// Downloads the model if it is missing (reporting the fraction done), then loads it once
    /// so the first Dictation is fast: ~0.3 s from cache, ~20 s on the first load after a download.
    public func prepare(progress: @escaping @Sendable (Double) -> Void) async throws {
        voz = try await Voz(progress: { progress($0.fraction) })
    }

    /// Downloads Uhm's model if it is missing (about 45 MB, reporting the fraction done), then loads it by
    /// analyzing a short silence, so removing fillers never waits for a load.
    public func prepareFillerModel(progress: @escaping @Sendable (Double) -> Void) async throws {
        try await uhm.download(progress: progress)
        _ = try await uhm.analyze(samples: [Float](repeating: 0, count: 1600), sampleRate: 16_000)
    }

    public func transcribe(_ recording: Recording) async throws -> String {
        guard let voz else { throw NotPrepared() }
        let samples = recording.samples, sampleRate = recording.sampleRate
        guard removesFillers else {
            return try await voz.transcribe(samples: samples, sampleRate: sampleRate).text
        }
        // Precision is the SDK's bias for automatic cuts; the type labels are unreliable and cost time.
        async let analysis = uhm.analyze(
            samples: samples, sampleRate: Int(sampleRate), options: .init(bias: .precision, includeTypes: false))
        let result = try await voz.transcribe(samples: samples, sampleRate: sampleRate)
        do {
            let fillers = try await analysis.fillers.map { $0.start...$0.end }
            return removeFillers(text: result.text, words: result.words, fillers: fillers)
        } catch {
            NSLog("Parlez: removing fillers failed, inserting Voz's Transcript: \(error)")
            return result.text
        }
    }

    private struct NotPrepared: Error {}
}

/// Removing fillers: the Transcript without the words Voz transcribed fully inside one of Uhm's filler spans.
/// Voz's `text` unchanged when no word is dropped, otherwise the kept words joined with spaces; Voz's words
/// carry their punctuation.
public func removeFillers(text: String, words: [Word], fillers: [ClosedRange<Double>]) -> String {
    let kept = words.filter { word in !fillers.contains { $0.lowerBound <= word.start && word.end <= $0.upperBound } }
    if kept.count == words.count { return text }
    return kept.map(\.text).joined(separator: " ")
}
