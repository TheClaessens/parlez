import AVFoundation
import Synchronization

/// The Microphone adapter: captures mono samples from the default input device.
@MainActor public final class AudioMicrophone: Microphone {
    private let engine = AVAudioEngine()
    private let samples = Samples()
    private var sampleRate: Double = 0

    public init() {}

    public func start() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        sampleRate = format.sampleRate
        samples.reset()
        input.installTap(onBus: 0, bufferSize: 4096, format: format, block: Self.tap(into: samples))
        do { try engine.start() } catch {
            input.removeTap(onBus: 0)
            throw error
        }
    }

    public func stop() -> Recording {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return Recording(samples: samples.take(), sampleRate: sampleRate)
    }

    /// Built outside the main actor: the tap runs on the audio thread.
    private nonisolated static func tap(into samples: Samples) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard let channels = buffer.floatChannelData else { return }
            samples.append(UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength)))
        }
    }
}

private final class Samples: Sendable {
    private let buffer = Mutex<[Float]>([])
    func reset() { buffer.withLock { $0 = [] } }
    func append(_ mono: UnsafeBufferPointer<Float>) { buffer.withLock { $0.append(contentsOf: mono) } }
    func take() -> [Float] { buffer.withLock { $0 } }
}
