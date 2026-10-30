import Voz

/// The Transcriber adapter: wraps Voz.
@MainActor public final class VozTranscriber: Transcriber {
    private let voz: Task<Voz, any Error>

    /// Starts loading Voz straight away, downloading the model first if it is missing.
    public init() {
        voz = Task { try await Voz() }
    }

    public func transcribe(_ recording: Recording) async throws -> String {
        try await voz.value.transcribe(samples: recording.samples, sampleRate: recording.sampleRate).text
    }
}
