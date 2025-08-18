//
//  AudioProcessor.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Accelerate
import AVFoundation
import CoreML
import Foundation

/// Real-time audio processor with FFT analysis and mood detection
class AudioProcessor: ObservableObject {
    // Audio engine components
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let fftProcessor: FFTProcessor

    // Buffers and processing
    private let bufferSize: Int = 4096
    private let sampleRate: Float = 44100.0
    private let processingQueue = DispatchQueue(label: "AudioProcessing", qos: .userInitiated)

    // Feature extraction and analysis
    @Published private(set) var currentFeatures: AudioFeatures?
    @Published private(set) var detectedMood: Mood = .neutral
    @Published private(set) var isAnalyzing: Bool = false

    // Buffer management
    private var activeBuffers: Set<AVAudioPCMBuffer> = []
    private var bufferPool: [AVAudioPCMBuffer] = []
    private let maxPoolSize = 10
    private let bufferLock = NSLock()
    private var memoryWarningObserver: NSObjectProtocol?
    private var totalMemoryUsage: Int = 0
    private let maxMemoryUsage = 50 * 1024 * 1024 // 50MB limit

    // Performance monitoring
    private var processingTimes: [TimeInterval] = []
    private let maxProcessingTimes = 50
    private var lastProcessingTime: TimeInterval = 0
    private var totalProcessedFrames: Int = 0
    @Published private(set) var averageProcessingTime: TimeInterval = 0
    @Published private(set) var bufferProcessingLoad: Double = 0

    init() {
        inputNode = audioEngine.inputNode
        fftProcessor = FFTProcessor(bufferSize: bufferSize, sampleRate: sampleRate)
        setupAudioSession()
        setupMemoryWarningObserver()
    }

    deinit {
        stopRealTimeAnalysis()
        cleanupBuffers()
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Buffer Management

    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    private func handleMemoryWarning() {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        cleanupBuffers()
        bufferPool.removeAll()
        totalMemoryUsage = 0
    }

    private func trackBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        let bufferSize = Int(buffer.frameLength * buffer.format.streamDescription.pointee.mBytesPerFrame)
        if totalMemoryUsage + bufferSize > maxMemoryUsage {
            handleMemoryPressure()
        }

        activeBuffers.insert(buffer)
        totalMemoryUsage += bufferSize
    }

    private func untrackBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        activeBuffers.remove(buffer)

        let bufferSize = Int(buffer.frameLength * buffer.format.streamDescription.pointee.mBytesPerFrame)
        totalMemoryUsage -= bufferSize

        if bufferPool.count < maxPoolSize {
            bufferPool.append(buffer) // Reuse buffer later
        }
    }

    private func handleMemoryPressure() {
        // Remove oldest buffers until we're under the memory limit
        while totalMemoryUsage > maxMemoryUsage * 3 / 4, !activeBuffers.isEmpty {
            if let oldestBuffer = activeBuffers.first {
                untrackBuffer(oldestBuffer)
            }
        }

        // Clear buffer pool under memory pressure
        bufferPool.removeAll()
    }

    private func cleanupBuffers() {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        activeBuffers.removeAll()
        bufferPool.removeAll()
        totalMemoryUsage = 0
    }

    private func getBufferFromPool(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        // Try to reuse a buffer from the pool
        if let index = bufferPool.firstIndex(where: { buffer in
            buffer.format == format && buffer.frameCapacity >= frameCapacity
        }) {
            return bufferPool.remove(at: index)
        }

        // Create new buffer if none available in pool
        return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)
    }

    // MARK: - Audio Processing

    func startRealTimeAnalysis(onFeaturesUpdate: @escaping (AudioFeatures) -> Void) {
        self.onFeaturesUpdate = onFeaturesUpdate

        guard !audioEngine.isRunning else {
            print("AudioProcessor - Already analyzing")
            return
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)
        inputNode
            .installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize),
                        format: inputFormat)
            { [weak self] buffer, _ in
                self?.trackBuffer(buffer)
                self?.processAudioBuffer(buffer)
            }

        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isAnalyzing = true
            }
        } catch {
            print("AudioProcessor - Failed to start audio engine: \(error)")
        }
    }

    func stopRealTimeAnalysis() {
        guard audioEngine.isRunning else { return }

        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        cleanupBuffers()

        DispatchQueue.main.async {
            self.isAnalyzing = false
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        let processStartTime = CACurrentMediaTime()

        processingQueue.async { [weak self] in
            guard let self else { return }

            autoreleasepool {
                defer {
                    self.untrackBuffer(buffer)
                    self.updatePerformanceMetrics(startTime: processStartTime)
                }

                guard let spectralFeatures = try? self.fftProcessor.processBuffer(buffer) else {
                    return
                }

                let audioFeatures = self.extractAudioFeatures(from: spectralFeatures)
                self.updateFeatureHistory(audioFeatures)

                DispatchQueue.main.async {
                    self.currentFeatures = audioFeatures
                    self.detectedMood = self.determineCurrentMood(from: audioFeatures)
                    self.onFeaturesUpdate?(audioFeatures)
                }
            }
        }
    }

    private func updatePerformanceMetrics(startTime: CFTimeInterval) {
        let processingTime = CACurrentMediaTime() - startTime

        processingTimes.append(processingTime)
        if processingTimes.count > maxProcessingTimes {
            processingTimes.removeFirst()
        }

        lastProcessingTime = processingTime
        averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)

        // Calculate buffer processing load (percentage of buffer duration spent processing)
        let bufferDuration = Double(bufferSize) / Double(sampleRate)
        bufferProcessingLoad = (processingTime / bufferDuration) * 100

        // Log warning if processing is taking too long
        if bufferProcessingLoad > 80 {
            print("Warning: High processing load (\(String(format: "%.1f", bufferProcessingLoad))%)")
            handleHighProcessingLoad()
        }

        totalProcessedFrames += bufferSize
    }

    private func handleHighProcessingLoad() {
        // Implement adaptive processing
        if bufferProcessingLoad > 90 {
            // Critical load - take immediate action
            cleanupBuffers()
            bufferPool.removeAll()
        } else {
            // High load - clean up old buffers
            while !activeBuffers.isEmpty, bufferProcessingLoad > 80 {
                if let oldestBuffer = activeBuffers.first {
                    untrackBuffer(oldestBuffer)
                }
            }
        }
    }

    private func extractAudioFeatures(from spectral: SpectralFeatures) -> AudioFeatures {
        // Calculate mood features
        let energy = calculateEnergy(
            bassEnergy: spectral.bassEnergy,
            midEnergy: spectral.midEnergy,
            trebleEnergy: spectral.trebleEnergy
        )

        let valence = calculateValence(
            brightness: spectral.brightness,
            harmonicRatio: spectral.harmonicRatio,
            spectralContrast: spectral.spectralContrast
        )

        let intensity = calculateIntensity(
            energy: energy,
            spectralFlatness: spectral.flatness,
            spectralCentroid: spectral.centroid
        )

        return AudioFeatures(
            energy: energy,
            valence: valence,
            intensity: intensity,
            complexity: spectral.spectralContrast,
            brightness: spectral.brightness,
            warmth: spectral.bassEnergy / (spectral.trebleEnergy + 1e-6)
        )
    }

    private func calculateEnergy(bassEnergy: Float, midEnergy: Float, trebleEnergy: Float) -> Float {
        // Weight the frequency bands based on perceptual importance
        bassEnergy * 0.4 + midEnergy * 0.4 + trebleEnergy * 0.2
    }

    private func calculateValence(brightness: Float, harmonicRatio: Float, spectralContrast: Float) -> Float {
        // Positive valence correlates with brightness and harmonic content
        let harmonicContribution = harmonicRatio * 0.4
        let brightnessContribution = brightness * 0.4
        let contrastContribution = (1.0 - spectralContrast) * 0.2 // Less contrast often indicates more positive mood

        return harmonicContribution + brightnessContribution + contrastContribution
    }

    private func calculateIntensity(energy: Float, spectralFlatness: Float, spectralCentroid: Float) -> Float {
        // Intensity combines energy with spectral characteristics
        let energyContribution = energy * 0.5
        let flatnessContribution = (1.0 - spectralFlatness) * 0.3 // Less flat usually means more intense
        let centroidContribution = (spectralCentroid / 10000.0) * 0.2 // Higher frequencies can indicate intensity

        return energyContribution + flatnessContribution + centroidContribution
    }

    private func calculateInstrumentalness(spectralContrast: Float, harmonicRatio: Float) -> Float {
        // Higher instrumentalness: High spectral contrast and harmonic ratio
        let contrast = min(1.0, spectralContrast / 20.0)
        let harmonic = min(1.0, harmonicRatio)
        return contrast * 0.6 + harmonic * 0.4
    }

    private func calculateSpeechiness(zeroCrossingRate: Float, spectralFlatness: Float) -> Float {
        // Higher speechiness: High zero crossing rate and spectral flatness
        let zcr = min(1.0, zeroCrossingRate / 3000.0)
        let flatness = min(1.0, spectralFlatness * 2.0)
        return zcr * 0.7 + flatness * 0.3
    }

    private func calculateLiveness(dynamicRange: Float, spectralFlux: Float) -> Float {
        // Higher liveness: High dynamic range and spectral flux
        let range = min(1.0, dynamicRange / 60.0)
        let flux = min(1.0, spectralFlux / 10.0)
        return range * 0.6 + flux * 0.4
    }

    private func calculateValence(bassEnergy: Float, midEnergy: Float, trebleEnergy: Float,
                                  brightness: Float) -> Float
    {
        // Higher valence: More treble and mid energy, moderate brightness
        let energyBalance = (midEnergy + trebleEnergy) / (bassEnergy + 1.0)
        let brightnessContribution = abs(brightness - 0.6) // Optimal brightness around 0.6
        return min(1.0, energyBalance * 0.7 + (1.0 - brightnessContribution) * 0.3)
    }

    private func calculateDanceability(tempo: Float, beatStrength: Float) -> Float {
        // Higher danceability: Strong beats and tempo between 90-130 BPM
        let tempoFactor = 1.0 - abs((tempo - 110.0) / 50.0) // Peak at 110 BPM
        return min(1.0, beatStrength * 0.7 + tempoFactor * 0.3)
    }

    private func calculateLiveness(spectral: SpectralFeatures) -> Float {
        // Higher liveness: More dynamic range and spectral flux
        min(1.0, (spectral.dynamicRange * 0.5 + spectral.spectralFlux * 0.5) / 20.0)
    }

    private func determineCurrentMood(from features: AudioFeatures) -> Mood {
        // Enhanced mood detection using multiple features
        if features.energy > 0.7, features.tempo > 120 {
            return features.valence > 0.6 ? .energetic : .angry
        } else if features.energy < 0.4, features.tempo < 100 {
            return features.valence > 0.5 ? .relaxed : .melancholic
        } else if features.valence > 0.7 {
            return .happy
        } else if features.energy > 0.5, features.valence > 0.4, features.valence < 0.6 {
            return .focused
        } else if features.energy < 0.6, features.valence > 0.5, features.valence < 0.8 {
            return .romantic
        }
        return .neutral
    }

    private func updateFeatureHistory(_ features: AudioFeatures) {
        featureHistory.append(features)
        if featureHistory.count > maxHistorySize {
            featureHistory.removeFirst()
        }
    }

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("AudioProcessor - Failed to setup audio session: \(error)")
        }
    }
}

// MARK: - Supporting Structures

struct AnalysisStatistics {
    let isActive: Bool
    let sampleRate: Float
    let bufferSize: Int
    let featuresInHistory: Int
    let currentMood: Mood
}
