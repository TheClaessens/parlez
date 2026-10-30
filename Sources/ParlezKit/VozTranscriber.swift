import Voz

/// The Transcriber adapter: wraps Voz. Setup prepares it; until then it has no model to transcribe with.
@MainActor public final class VozTranscriber: Transcriber {
    private var voz: Voz?

    public init() {}

    /// Whether the model is on disk, so Setup knows whether its model step needs a download.
    public static var isModelDownloaded: Bool { Voz.isDownloaded() }

    /// Downloads the model if it is missing (reporting the fraction done), then loads it once
    /// so the first Dictation is fast: ~0.3 s from cache, ~20 s on the first load after a download.
    public func prepare(progress: @escaping @Sendable (Double) -> Void) async throws {
        voz = try await Voz(progress: { progress($0.fraction) })
    }

    public func transcribe(_ recording: Recording) async throws -> String {
        guard let voz else { throw NotPrepared() }
        return try await voz.transcribe(samples: recording.samples, sampleRate: recording.sampleRate).text
    }

    private struct NotPrepared: Error {}
}
