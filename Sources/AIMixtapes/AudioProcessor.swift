//
//  AudioProcessor.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import AVFoundation
import CoreML
import Accelerate

/// Real-time audio processor with FFT analysis and mood detection
class AudioProcessor: ObservableObject {
    // MARK: - Properties
    
    // Audio engine components
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let fftProcessor: FFTProcessor
    
    // Buffers and processing
    private let bufferSize: Int = 4096
    private let sampleRate: Float = 44100.0
    private let processingQueue = DispatchQueue(label: "AudioProcessing", qos: .userInitiated)
    
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
    @Published private(set) var memoryUsage: Int = 0
    @Published private(set) var analysisStatistics: AnalysisStatistics?
    
    // Analysis state
    @Published private(set) var currentFeatures: AudioFeatures?
    @Published private(set) var detectedMood: Mood = .neutral
    @Published private(set) var isAnalyzing: Bool = false
    private var featureHistory: [AudioFeatures] = []
    private let maxHistorySize = 10
    private var onFeaturesUpdate: ((AudioFeatures) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        self.inputNode = audioEngine.inputNode
        self.fftProcessor = FFTProcessor(maxFrameSize: bufferSize, sampleRate: sampleRate)
        setupAudioSession()
        setupMemoryWarningObserver()
        updateAnalysisStatistics()
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        stopRealTimeAnalysis()
        cleanupBuffers()
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryWarningObserver() {
        #if os(iOS)
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        #else
        // For macOS - alternative memory pressure observation could be implemented here
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, // Using as placeholder
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // On macOS we could use Memory pressure API or just regular cleanup
            self?.handleMemoryWarning()
        }
        #endif
    }
    
    private func handleMemoryWarning() {
        cleanupBuffers()
        bufferPool.removeAll()
    }
    
    private func cleanupBuffers() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        activeBuffers.removeAll()
        totalMemoryUsage = 0
        
        DispatchQueue.main.async {
            self.memoryUsage = 0
            self.updateAnalysisStatistics()
        }
    }
    
    // MARK: - Buffer Management
    
    private func trackBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        let bufferSize = Int(buffer.frameLength * buffer.format.streamDescription.pointee.mBytesPerFrame)
        
        // Check if adding this buffer would exceed memory limit
        if totalMemoryUsage + bufferSize > maxMemoryUsage {
            handleMemoryPressure()
            return
        }
        
        activeBuffers.insert(buffer)
        totalMemoryUsage += bufferSize
        
        DispatchQueue.main.async {
            self.memoryUsage = self.totalMemoryUsage
            self.updateAnalysisStatistics()
        }
    }
    
    private func untrackBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        if activeBuffers.remove(buffer) != nil {
            let bufferSize = Int(buffer.frameLength * buffer.format.streamDescription.pointee.mBytesPerFrame)
            totalMemoryUsage -= bufferSize
            
            // Return buffer to pool if space available
            if bufferPool.count < maxPoolSize {
                bufferPool.append(buffer)
            }
            
            DispatchQueue.main.async {
                self.memoryUsage = self.totalMemoryUsage
                self.updateAnalysisStatistics()
            }
        }
    }
    
    private func handleMemoryPressure() {
        // Remove oldest buffers until we're under the limit
        while totalMemoryUsage > maxMemoryUsage * 3/4 && !activeBuffers.isEmpty {
            if let oldestBuffer = activeBuffers.first {
                untrackBuffer(oldestBuffer)
            }
        }
        
        // Clear buffer pool
        bufferPool.removeAll()
    }
    
    // MARK: - Performance Monitoring
    
    private func updatePerformanceMetrics(startTime: CFTimeInterval) {
        let processingTime = CACurrentMediaTime() - startTime
        
        processingTimes.append(processingTime)
        if processingTimes.count > maxProcessingTimes {
            processingTimes.removeFirst()
        }
        
        lastProcessingTime = processingTime
        
        DispatchQueue.main.async {
            self.averageProcessingTime = self.processingTimes.reduce(0, +) / Double(self.processingTimes.count)
            
            // Calculate buffer processing load (percentage of buffer duration spent processing)
            let bufferDuration = Double(self.bufferSize) / Double(self.sampleRate)
            self.bufferProcessingLoad = (processingTime / bufferDuration) * 100
            
            self.updateAnalysisStatistics()
        }
        
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
            while !activeBuffers.isEmpty && bufferProcessingLoad > 80 {
                if let oldestBuffer = activeBuffers.first {
                    untrackBuffer(oldestBuffer)
                }
            }
        }
    }
    
    private func updateAnalysisStatistics() {
        analysisStatistics = getAnalysisStatistics()
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            defer { 
                self.untrackBuffer(buffer)
                self.updatePerformanceMetrics(startTime: startTime)
            }
            
            guard let spectralFeatures = self.fftProcessor.processBuffer(buffer) else {
                return
            }
            
            // Extract features from spectral analysis
            if let audioFeatures = self.extractAudioFeatures(from: spectralFeatures) {
                self.updateFeatureHistory(audioFeatures)
                
                DispatchQueue.main.async {
                    self.currentFeatures = audioFeatures
                    self.detectedMood = self.determineCurrentMood(from: audioFeatures)
                    self.updateAnalysisStatistics()
                    self.onFeaturesUpdate?(audioFeatures)
                }
            }
        }
    }
    
    // MARK: - Feature Extraction and Analysis
    
    private func extractAudioFeatures(from spectral: SpectralFeatures) -> AudioFeatures? {
        // Calculate core features
        let energy = calculateEnergy(
            bassEnergy: spectral.bassEnergy,
            midEnergy: spectral.midEnergy,
            trebleEnergy: spectral.trebleEnergy,
            brightness: spectral.brightness
        )
        
        let valence = calculateValence(
            brightness: spectral.brightness,
            harmonicRatio: spectral.harmonicRatio,
            spectralContrast: spectral.spectralContrast,
            bassEnergy: spectral.bassEnergy,
            midEnergy: spectral.midEnergy,
            trebleEnergy: spectral.trebleEnergy
        )
        
        // Calculate danceability
        let danceability = calculateDanceability(
            tempo: spectral.estimatedTempo,
            beatStrength: spectral.beatStrength
        )
        
        // Calculate acousticness
        let acousticness = 1.0 - (spectral.bassEnergy + spectral.trebleEnergy) / 2.0
        
        // Calculate instrumentalness 
        let instrumentalness = calculateInstrumentalness(
            spectralContrast: spectral.spectralContrast,
            harmonicRatio: spectral.harmonicRatio
        )
        
        // Calculate speechiness
        let speechiness = calculateSpeechiness(
            zeroCrossingRate: spectral.zeroCrossingRate,
            spectralFlatness: spectral.spectralFlatness
        )
        
        // Calculate liveness
        let liveness = calculateLiveness(
            dynamicRange: spectral.dynamicRange,
            spectralFlux: spectral.spectralFlux
        )
        
        return AudioFeatures(
            tempo: spectral.estimatedTempo,
            energy: energy,
            valence: valence,
            danceability: danceability,
            acousticness: acousticness,
            instrumentalness: instrumentalness,
            speechiness: speechiness,
            liveness: liveness
        )
    }
    
    private func calculateEnergy(bassEnergy: Float, midEnergy: Float, trebleEnergy: Float, brightness: Float) -> Float {
        // Higher energy: More bass and treble energy, higher brightness
        let weightedEnergy = (bassEnergy * 0.4 + midEnergy * 0.3 + trebleEnergy * 0.3)
        let brightnessContribution = min(1.0, brightness * 1.2)
        return min(1.0, weightedEnergy * 0.7 + brightnessContribution * 0.3)
    }
    
    private func calculateValence(brightness: Float, harmonicRatio: Float, spectralContrast: Float, 
                                bassEnergy: Float, midEnergy: Float, trebleEnergy: Float) -> Float {
        // Positive valence correlates with brightness and harmonic content
        let harmonicContribution = harmonicRatio * 0.3
        let brightnessContribution = brightness * 0.3
        
        // Energy balance is also important for valence
        let energyBalance = (midEnergy + trebleEnergy) / (bassEnergy + 1.0)
        let energyContribution = min(1.0, energyBalance) * 0.4
        
        return min(1.0, harmonicContribution + brightnessContribution + energyContribution)
    }
    
    private func calculateInstrumentalness(spectralContrast: Float, harmonicRatio: Float) -> Float {
        // Higher instrumentalness: High spectral contrast and harmonic ratio
        let contrast = min(1.0, spectralContrast / 20.0)
        let harmonic = min(1.0, harmonicRatio)
        return (contrast * 0.6 + harmonic * 0.4)
    }
    
    private func calculateSpeechiness(zeroCrossingRate: Float, spectralFlatness: Float) -> Float {
        // Higher speechiness: High zero crossing rate and spectral flatness
        let zcr = min(1.0, zeroCrossingRate / 3000.0)
        let flatness = min(1.0, spectralFlatness * 2.0)
        return (zcr * 0.7 + flatness * 0.3)
    }
    
    private func calculateLiveness(dynamicRange: Float, spectralFlux: Float) -> Float {
        // Higher liveness: High dynamic range and spectral flux
        let range = min(1.0, dynamicRange / 60.0)
        let flux = min(1.0, spectralFlux / 10.0)
        return (range * 0.6 + flux * 0.4)
    }
    
    private func calculateDanceability(tempo: Float, beatStrength: Float) -> Float {
        // Higher danceability: Strong beats and tempo between 90-130 BPM
        let tempoFactor = 1.0 - abs((tempo - 110.0) / 50.0) // Peak at 110 BPM
        return min(1.0, (beatStrength * 0.7 + tempoFactor * 0.3))
    }
    
    private func calculateLiveness(spectral: SpectralFeatures) -> Float {
        // Higher liveness: More dynamic range and spectral flux
        return min(1.0, (spectral.dynamicRange * 0.5 + spectral.spectralFlux * 0.5) / 20.0)
    }
    
    // MARK: - Mood Detection
    
    private func determineCurrentMood(from features: AudioFeatures) -> Mood {
        // Enhanced mood detection using multiple features
        if features.energy > 0.7 && features.tempo > 120 {
            return features.valence > 0.6 ? .energetic : .angry
        } else if features.energy < 0.4 && features.tempo < 100 {
            return features.valence > 0.5 ? .relaxed : .melancholic
        } else if features.valence > 0.7 {
            return .happy
        } else if features.energy > 0.5 && features.valence > 0.4 && features.valence < 0.6 {
            return .focused
        } else if features.energy < 0.6 && features.valence > 0.5 && features.valence < 0.8 {
            return .romantic
        }
        return .neutral
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("AudioProcessor - Failed to setup audio session: \(error)")
        }
        #endif
    }
}

// MARK: - Supporting Structures

/// Statistics about the current audio analysis process
struct AnalysisStatistics: Codable {
    let isActive: Bool
    let sampleRate: Float
    let bufferSize: Int
    let featuresInHistory: Int
    let currentMood: Mood
    let averageProcessingTime: Double
    let memoryUsage: Int
    let bufferLoad: Double
}

/// Extended audio features structure with all Spotify-like features
struct AudioFeatures: Codable {
    let tempo: Float              // BPM
    let energy: Float             // 0-1, intensity
    let valence: Float            // 0-1, positivity
    let danceability: Float       // 0-1, dance suitability
    let acousticness: Float       // 0-1, acoustic confidence
    let instrumentalness: Float   // 0-1, no vocals confidence
    let speechiness: Float        // 0-1, spoken words
    let liveness: Float           // 0-1, live performance
    let intensity: Float          // 0-1, intensity
    let complexity: Float         // 0-1, complexity
    let brightness: Float         // 0-1, brightness
    let warmth: Float             // 0-1, warmth
}
