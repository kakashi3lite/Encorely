import Accelerate
import AudioKit
import AVFAudio
import Foundation
import SoundpipeAudioKit

/// Delegate protocol for real-time feature updates
public protocol FeatureExtractorDelegate: AnyObject {
    func featureExtractor(_ extractor: FeatureExtractor, didExtract features: AudioFeatures)
    func featureExtractor(_ extractor: FeatureExtractor, didEncounterError error: Error)
}

public class FeatureExtractor {
    // MARK: - Properties

    private let fftProcessor: FFTProcessor
    private let fftSize: Int
    private let sampleRate: Double
    public weak var delegate: FeatureExtractorDelegate?

    // AudioKit nodes
    private let engine = AudioEngine()
    private var pitchTap: PitchTap?
    private var fftTap: FFTTap?
    private var amplitudeTap: AmplitudeTap?
    private var playerNode: AudioPlayer?

    // Buffer management
    private let bufferQueue = DispatchQueue(label: "com.aimixtapes.featureextractor.buffer",
                                            qos: .userInteractive)
    private let analysisQueue = DispatchQueue(label: "com.aimixtapes.featureextractor.analysis",
                                              qos: .userInitiated)
    private var bufferPool: BufferPool
    private let analysisFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)

    // Feature extraction state
    private var isExtracting = false
    private var lastFeatureTimestamp: TimeInterval = 0
    private var featureHistory: RingBuffer<AudioFeatures>

    // Performance monitoring
    private var processingLoad: Double = 0
    private var averageProcessingTime: TimeInterval = 0

    // MARK: - Initialization

    public init?(fftSize: Int = 2048, sampleRate: Double = 44100, historySize: Int = 10) {
        guard let processor = FFTProcessor(size: fftSize, sampleRate: Float(sampleRate)) else { return nil }

        fftProcessor = processor
        self.fftSize = fftSize
        self.sampleRate = sampleRate
        bufferPool = BufferPool(maxBuffers: 10, format: analysisFormat)
        featureHistory = RingBuffer(capacity: historySize)

        setupAudioKit()
    }

    deinit {
        cleanup()
    }

    // MARK: - Setup

    private func setupAudioKit() {
        // Initialize player node with high-quality settings
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate,
                                         channels: 1)
        playerNode = AudioPlayer()

        guard let player = playerNode else { return }

        // Connect nodes with proper buffer sizes
        engine.output = player

        // Initialize analysis taps with managed buffers
        setupAnalysisTaps(on: player)

        // Start engine
        do {
            try engine.start()
        } catch {
            delegate?.featureExtractor(self, didEncounterError: error)
        }
    }

    private func setupAnalysisTaps(on node: Node) {
        // Configure pitch tracking
        pitchTap = PitchTap(node) { [weak self] pitch, amp in
            self?.processPitchData(pitch: pitch[0], amplitude: amp[0])
        }

        // Configure FFT analysis
        fftTap = FFTTap(node) { [weak self] fftData in
            self?.processFFTData(fftData)
        }

        // Configure amplitude tracking
        amplitudeTap = AmplitudeTap(node) { [weak self] amp in
            self?.processAmplitudeData(amplitude: amp[0])
        }
    }

    // MARK: - Public Interface

    /// Start real-time feature extraction
    public func startExtracting() {
        bufferQueue.async { [weak self] in
            guard let self else { return }

            isExtracting = true
            pitchTap?.start()
            fftTap?.start()
            amplitudeTap?.start()
        }
    }

    /// Stop feature extraction
    public func stopExtracting() {
        bufferQueue.async { [weak self] in
            guard let self else { return }

            isExtracting = false
            pitchTap?.stop()
            fftTap?.stop()
            amplitudeTap?.stop()
        }
    }

    /// Extract features from provided samples
    public func extractFeatures(from samples: [Float]) -> AudioFeatures {
        let startTime = CACurrentMediaTime()

        // Get buffer from pool
        guard let buffer = bufferPool.obtainBuffer() else {
            return AudioFeatures()
        }

        defer {
            bufferPool.returnBuffer(buffer)
            updatePerformanceMetrics(startTime: startTime)
        }

        // Process in chunks to manage memory
        return autoreleasepool {
            // Extract spectral features
            guard let spectralFeatures = fftProcessor.analyzeSpectralFeatures(buffer) else {
                return AudioFeatures()
            }

            // Calculate basic features
            let rms = calculateAmplitude(samples)
            let (pitch, confidence) = calculatePitch(samples)
            let zcr = calculateZeroCrossingRate(samples)

            // Create feature set
            var features = AudioFeatures()
            features.rms = rms
            features.zeroCrossingRate = zcr
            features.spectralCentroid = spectralFeatures.centroid
            features.spectralRolloff = spectralFeatures.rolloff
            features.spectralFlatness = spectralFeatures.flatness
            features.spectralSpread = spectralFeatures.spread
            features.pitch = pitch
            features.pitchConfidence = confidence
            features.bassEnergy = spectralFeatures.bassEnergy
            features.midEnergy = spectralFeatures.midEnergy
            features.trebleEnergy = spectralFeatures.trebleEnergy
            features.harmonicRatio = spectralFeatures.harmonicRatio
            features.brightness = spectralFeatures.brightness

            // Update history
            featureHistory.write(features)

            return features
        }
    }

    // MARK: - Private Processing Methods

    private func processPitchData(pitch: Float, amplitude: Float) {
        guard isExtracting else { return }
        analysisQueue.async { [weak self] in
            // Process pitch data
            self?.updateFeatures(withPitch: pitch, amplitude: amplitude)
        }
    }

    private func processFFTData(_ fftData: [Float]) {
        guard isExtracting else { return }
        analysisQueue.async { [weak self] in
            guard let self else { return }

            // Process FFT data and extract spectral features
            autoreleasepool {
                if let spectralFeatures = self.fftProcessor.analyzeSpectralFeatures(fftData) {
                    self.updateFeatures(withSpectral: spectralFeatures)
                }
            }
        }
    }

    private func processAmplitudeData(amplitude: Float) {
        guard isExtracting else { return }
        analysisQueue.async { [weak self] in
            self?.updateFeatures(withAmplitude: amplitude)
        }
    }

    private func calculateAmplitude(_ samples: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms
    }

    private func calculatePitch(_ samples: [Float]) -> (pitch: Float, confidence: Float) {
        // Use YIN pitch detection algorithm for better accuracy
        var frequencies = [Float](repeating: 0, count: samples.count / 2)
        var confidences = [Float](repeating: 0, count: samples.count / 2)

        // Implementation of YIN algorithm
        // 1. Autocorrelation
        var autocorr = [Float](repeating: 0, count: samples.count / 2)
        vDSP_conv(samples, 1, samples, 1, &autocorr, 1, vDSP_Length(samples.count / 2))

        // 2. Difference function
        var diff = [Float](repeating: 0, count: samples.count / 2)
        for tau in 0 ..< samples.count / 2 {
            for i in 0 ..< samples.count - tau {
                let delta = samples[i] - samples[i + tau]
                diff[tau] += delta * delta
            }
        }

        // 3. Cumulative mean normalized difference
        var cmnd = [Float](repeating: 0, count: samples.count / 2)
        cmnd[0] = 1
        var sum = diff[0]
        for tau in 1 ..< samples.count / 2 {
            sum += diff[tau]
            cmnd[tau] = diff[tau] * Float(tau) / sum
        }

        // 4. Find pitch
        var minValue: Float = 1.0
        var minTau = 0
        for tau in 2 ..< samples.count / 2 {
            if cmnd[tau] < minValue {
                minValue = cmnd[tau]
                minTau = tau
            }
        }

        let pitch = Float(sampleRate) / Float(minTau)
        let confidence = 1.0 - minValue

        return (pitch, confidence)
    }

    private func calculateZeroCrossingRate(_ samples: [Float]) -> Float {
        var crossings = 0
        for i in 1 ..< samples.count {
            if (samples[i] * samples[i - 1]) < 0 {
                crossings += 1
            }
        }
        return Float(crossings) / Float(samples.count)
    }

    // MARK: - Feature Updates

    private func updateFeatures(withPitch pitch: Float, amplitude: Float) {
        var currentFeatures = featureHistory.latest ?? AudioFeatures()
        currentFeatures.pitch = pitch
        currentFeatures.rms = amplitude
        notifyFeatureUpdate(currentFeatures)
    }

    private func updateFeatures(withSpectral features: SpectralFeatures) {
        var currentFeatures = featureHistory.latest ?? AudioFeatures()
        currentFeatures.spectralCentroid = features.centroid
        currentFeatures.spectralRolloff = features.rolloff
        currentFeatures.spectralFlatness = features.flatness
        currentFeatures.spectralSpread = features.spread
        currentFeatures.bassEnergy = features.bassEnergy
        currentFeatures.midEnergy = features.midEnergy
        currentFeatures.trebleEnergy = features.trebleEnergy
        currentFeatures.harmonicRatio = features.harmonicRatio
        currentFeatures.brightness = features.brightness
        notifyFeatureUpdate(currentFeatures)
    }

    private func updateFeatures(withAmplitude amplitude: Float) {
        var currentFeatures = featureHistory.latest ?? AudioFeatures()
        currentFeatures.rms = amplitude
        notifyFeatureUpdate(currentFeatures)
    }

    private func notifyFeatureUpdate(_ features: AudioFeatures) {
        let now = CACurrentMediaTime()
        if now - lastFeatureTimestamp >= 0.05 { // 20Hz update rate
            lastFeatureTimestamp = now
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                delegate?.featureExtractor(self, didExtract: features)
            }
        }
    }

    // MARK: - Performance Monitoring

    private func updatePerformanceMetrics(startTime: CFTimeInterval) {
        let processingTime = CACurrentMediaTime() - startTime

        // Update average processing time with exponential moving average
        averageProcessingTime = 0.9 * averageProcessingTime + 0.1 * processingTime

        // Calculate processing load (percentage of buffer duration spent processing)
        let bufferDuration = Double(fftSize) / sampleRate
        processingLoad = (processingTime / bufferDuration) * 100

        // Log warning if processing is taking too long
        if processingLoad > 80 {
            print("Warning: High processing load (\(String(format: "%.1f", processingLoad))%)")
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        stopExtracting()
        engine.stop()
        bufferPool.removeAllBuffers()
    }
}

// MARK: - Buffer Pool Implementation

private class BufferPool {
    private var availableBuffers: [AVAudioPCMBuffer] = []
    private let maxBuffers: Int
    private let format: AVAudioFormat
    private let lock = NSLock()

    init(maxBuffers: Int, format: AVAudioFormat) {
        self.maxBuffers = maxBuffers
        self.format = format
    }

    func obtainBuffer() -> AVAudioPCMBuffer? {
        lock.lock()
        defer { lock.unlock() }

        if let buffer = availableBuffers.popLast() {
            return buffer
        }

        if availableBuffers.count < maxBuffers {
            return AVAudioPCMBuffer(pcmFormat: format,
                                    frameCapacity: AVAudioFrameCount(4096))
        }

        return nil
    }

    func returnBuffer(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }

        buffer.frameLength = 0
        if availableBuffers.count < maxBuffers {
            availableBuffers.append(buffer)
        }
    }

    func removeAllBuffers() {
        lock.lock()
        defer { lock.unlock() }

        availableBuffers.removeAll()
    }
}

// MARK: - Ring Buffer Implementation

private class RingBuffer<T> {
    private var buffer: [T?]
    private var writeIndex = 0
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        buffer = Array(repeating: nil, count: capacity)
    }

    func write(_ element: T) {
        buffer[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
    }

    var latest: T? {
        let index = (writeIndex - 1 + capacity) % capacity
        return buffer[index]
    }

    func getHistory() -> [T] {
        buffer.compactMap { $0 }
    }
}
