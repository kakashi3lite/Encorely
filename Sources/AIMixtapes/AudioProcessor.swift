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
import Domain

/// Real-time audio processor with FFT analysis and mood detection
class AudioProcessor: ObservableObject {
    // MARK: - Properties
    
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let fftProcessor: FFTProcessor
    private let audioBufferPool: AudioBufferPool
    
    // Audio configuration
    private let bufferSize: Int = 4096
    private let sampleRate: Float = 44100.0
    private let processingQueue = DispatchQueue(label: "AudioProcessing", qos: .userInitiated)
    
    // Memory management
    private var memoryWarningObserver: NSObjectProtocol?
    private var totalMemoryUsage: Int = 0
    private let maxMemoryUsage = 50 * 1024 * 1024 // 50MB limit
    private var avgMemoryUsagePerBuffer: Double = 0
    private var activeBuffers = Set<ManagedAudioBuffer>()
    private let bufferLock = NSLock()
    
    // Performance metrics
    private var processingTimes: [TimeInterval] = []
    private let maxProcessingTimes = 50
    private var lastProcessingTime: TimeInterval = 0
    private var totalProcessedFrames: Int = 0
    @Published private(set) var averageProcessingTime: TimeInterval = 0
    @Published private(set) var bufferProcessingLoad: Double = 0
    @Published private(set) var memoryUsage: Int = 0
    @Published private(set) var analysisStatistics: AnalysisStatistics?
    
    // Feature extraction and analysis
    @Published private(set) var currentFeatures: AudioFeatures?
    @Published private(set) var detectedMood: Mood = .neutral
    @Published private(set) var isAnalyzing: Bool = false
    
    // MARK: - Initialization
    
    init() {
        self.inputNode = audioEngine.inputNode
        self.fftProcessor = FFTProcessor(maxFrameSize: bufferSize, sampleRate: sampleRate)
        self.audioBufferPool = AudioBufferPool(maxBuffers: 10, bufferSize: UInt32(bufferSize))
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
        // Setup memory warning notifications for both platforms
        #if os(iOS)
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        #else
        // For macOS - using periodic memory checks
        let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkMemoryPressure()
        }
        RunLoop.main.add(timer, forMode: .common)
        #endif
    }
    
    private func handleMemoryWarning() {
        cleanupBuffers()
    }
    
    private func cleanupBuffers() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        activeBuffers.removeAll()
        totalMemoryUsage = 0
        avgMemoryUsagePerBuffer = 0
        
        // Release pool buffers
        audioBufferPool.releaseAllBuffers()
        
        DispatchQueue.main.async {
            self.memoryUsage = 0
            self.updateAnalysisStatistics()
        }
    }
    
    private func trackBuffer(_ buffer: ManagedAudioBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        let memoryDelta = buffer.memorySize
        
        if totalMemoryUsage + memoryDelta > maxMemoryUsage {
            handleMemoryPressure()
        }
        
        activeBuffers.insert(buffer)
        totalMemoryUsage += memoryDelta
        
        // Update average memory usage per buffer
        let bufferCount = activeBuffers.count
        avgMemoryUsagePerBuffer = (avgMemoryUsagePerBuffer * Double(bufferCount - 1) + Double(memoryDelta)) / Double(bufferCount)
        
        DispatchQueue.main.async {
            self.memoryUsage = self.totalMemoryUsage
            self.updateAnalysisStatistics()
        }
    }
    
    private func untrackBuffer(_ buffer: ManagedAudioBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        if activeBuffers.remove(buffer) != nil {
            totalMemoryUsage -= buffer.memorySize
            audioBufferPool.returnBuffer(buffer)
            
            DispatchQueue.main.async {
                self.memoryUsage = self.totalMemoryUsage
                self.updateAnalysisStatistics()
            }
        }
    }
    
    private func handleMemoryPressure() {
        // Progressive cleanup based on pressure level
        let memoryPressure = Double(totalMemoryUsage) / Double(maxMemoryUsage)
        
        if memoryPressure > 0.9 { // Critical pressure
            cleanupBuffers()
        } else if memoryPressure > 0.8 { // High pressure
            audioBufferPool.reducePoolSize()
            
            // Remove oldest active buffers
            let sortedBuffers = activeBuffers.sorted { $0.idleTime > $1.idleTime }
            let removeCount = sortedBuffers.count / 2
            
            for buffer in sortedBuffers.prefix(removeCount) {
                untrackBuffer(buffer)
            }
        } else if memoryPressure > 0.7 { // Moderate pressure
            audioBufferPool.reducePoolSize()
        }
        
        updateAnalysisStatistics()
    }
    
    private func checkMemoryPressure() {
        let pressure = Double(totalMemoryUsage) / Double(maxMemoryUsage)
        if pressure > 0.7 {
            handleMemoryPressure()
        }
    }
    
    private func getOrCreateBuffer(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> ManagedAudioBuffer? {
        if let buffer = audioBufferPool.getBuffer() {
            trackBuffer(buffer)
            return buffer
        }
        return nil // Let pool handle buffer creation
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
            
            if self.bufferProcessingLoad > 80 {
                self.handleHighProcessingLoad()
            }
            
            self.updateAnalysisStatistics()
        }
        
        totalProcessedFrames += bufferSize
    }
    
    private func handleHighProcessingLoad() {
        // Implement adaptive processing based on load
        if bufferProcessingLoad > 90 {
            // Critical load - take immediate action
            cleanupBuffers()
            audioBufferPool.releaseAllBuffers()
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
        let poolMetrics = audioBufferPool.getPoolMetrics()
        analysisStatistics = AnalysisStatistics(
            totalFramesProcessed: totalProcessedFrames,
            averageProcessingTime: averageProcessingTime,
            currentMemoryUsage: memoryUsage,
            peakMemoryUsage: poolMetrics.peakMemoryUsage,
            bufferAllocationCount: poolMetrics.totalAllocations,
            bufferReuseCount: poolMetrics.reuseCount,
            missedBufferRequests: poolMetrics.missedRequests,
            averageMemoryPerBuffer: Int(avgMemoryUsagePerBuffer)
        )
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
            let audioFeatures = self.extractAudioFeatures(from: spectralFeatures)
            self.updateFeatureHistory(audioFeatures)
            
            DispatchQueue.main.async {
                self.currentFeatures = audioFeatures
                self.detectedMood = self.determineCurrentMood(from: audioFeatures)
                self.updateAnalysisStatistics()
                self.onFeaturesUpdate?(audioFeatures)
            }
        }
    }
    
    // MARK: - Feature Extraction and Analysis
    
    private func extractAudioFeatures(from spectral: SpectralFeatures) -> AudioFeatures {
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
            spectralContrast: spectral.spectralContrast
        )
        
        return AudioFeatures(
            tempo: spectral.estimatedTempo,
            energy: energy,
            valence: valence,
            danceability: calculateDanceability(tempo: spectral.estimatedTempo, beatStrength: spectral.beatStrength),
            acousticness: 1.0 - (spectral.bassEnergy + spectral.trebleEnergy) / 2.0,
            instrumentalness: calculateInstrumentalness(spectralContrast: spectral.spectralContrast, harmonicRatio: spectral.harmonicRatio),
            speechiness: calculateSpeechiness(zeroCrossingRate: spectral.zeroCrossingRate, spectralFlatness: spectral.flatness),
            liveness: calculateLiveness(dynamicRange: spectral.dynamicRange, crest: spectral.crest),
            spectralCentroid: spectral.centroid,
            spectralRolloff: spectral.rolloff,
            zeroCrossingRate: spectral.zeroCrossingRate,
            loudness: nil,
            dynamicRange: spectral.dynamicRange
        )
    }
    
    // Update mood detection to use the Domain AudioFeatures
    private func determineCurrentMood(from features: AudioFeatures) -> Mood {
        features.estimatedMood.toMood()
    }
}

// Convert between EstimatedMood and Mood
private extension EstimatedMood {
    func toMood() -> Mood {
        switch self {
        case .energetic: return .energetic
        case .relaxed: return .relaxed
        case .happy: return .happy
        case .melancholic: return .melancholic
        case .focused: return .focused
        case .neutral: return .neutral
        }
    }
}

// MARK: - Supporting Structures

/// Statistics about the current audio analysis process
struct AnalysisStatistics: Codable {
    let totalFramesProcessed: Int
    let averageProcessingTime: TimeInterval
    let currentMemoryUsage: Int
    let peakMemoryUsage: Int
    let bufferAllocationCount: Int
    let bufferReuseCount: Int
    let missedBufferRequests: Int
    let averageMemoryPerBuffer: Int
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
