import AVFoundation
import Foundation

/// Handles batch processing of audio buffers for improved performance
final class AudioBatchProcessor {
    private let maxBatchSize: Int
    private var currentBatch: [ManagedAudioBuffer] = []
    private var processingTimer: Timer?
    private let processingInterval: TimeInterval = 0.1

    private let processingQueue = DispatchQueue(
        label: "com.aimixtapes.batchprocessing",
        qos: .userInitiated
    )

    init(maxBatchSize: Int) {
        self.maxBatchSize = maxBatchSize
        setupProcessingTimer()
    }

    private func setupProcessingTimer() {
        processingTimer = Timer.scheduledTimer(
            withTimeInterval: processingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.processCurrentBatchIfNeeded()
        }
        RunLoop.main.add(processingTimer!, forMode: .common)
    }

    func addBuffer(_ buffer: ManagedAudioBuffer) {
        currentBatch.append(buffer)
        if currentBatch.count >= maxBatchSize {
            processCurrentBatch()
        }
    }

    func processBatch(_ buffers: [ManagedAudioBuffer], completion: @escaping ([AudioFeatures]) -> Void) {
        processingQueue.async { [weak self] in
            autoreleasepool {
                let features = self?.processBatchSync(buffers) ?? []
                DispatchQueue.main.async {
                    completion(features)
                }
            }
        }
    }

    private func processCurrentBatchIfNeeded() {
        guard !currentBatch.isEmpty else { return }
        processCurrentBatch()
    }

    private func processCurrentBatch() {
        let batchToProcess = currentBatch
        currentBatch.removeAll()

        processingQueue.async { [weak self] in
            autoreleasepool {
                _ = self?.processBatchSync(batchToProcess)
            }
        }
    }

    private func processBatchSync(_ buffers: [ManagedAudioBuffer]) -> [AudioFeatures] {
        var features: [AudioFeatures] = []

        for buffer in buffers {
            autoreleasepool {
                if let processed = processBuffer(buffer) {
                    features.append(processed)
                }
            }
        }

        return features
    }

    private func processBuffer(_ buffer: ManagedAudioBuffer) -> AudioFeatures? {
        // Extract features from buffer
        guard let pcmBuffer = buffer.buffer else { return nil }

        var features = AudioFeatures()

        if let channelData = pcmBuffer.floatChannelData?[0] {
            let frameCount = Int(pcmBuffer.frameLength)

            // Calculate RMS (energy)
            var rms: Float = 0
            vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))
            features.energy = rms

            // Calculate peak
            var peak: Float = 0
            vDSP_maxv(channelData, 1, &peak, vDSP_Length(frameCount))
            features.peak = peak

            // Calculate average magnitude
            var mean: Float = 0
            vDSP_meamgv(channelData, 1, &mean, vDSP_Length(frameCount))
            features.averageMagnitude = mean
        }

        return features
    }

    func reset() {
        currentBatch.removeAll()
    }

    deinit {
        processingTimer?.invalidate()
    }
}
