//
//  AudioAnalysisService.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import AVFoundation
import Accelerate
import CoreML
import Combine
import os.log
import SwiftUI

/// Custom errors for audio analysis operations
enum AudioAnalysisError: LocalizedError {
    case fileNotFound(URL)
    case invalidAudioFormat(String)
    case bufferProcessingFailed(String)
    case modelLoadingFailed(String)
    case coreMLInferenceFailed(String)
    case unsupportedAudioFile(String)
    case insufficientAudioData
    case analysisTimeout
    case permissionDenied
    case deviceResourcesUnavailable
    case serviceUnavailable
    case maxRetriesExceeded
    case networkUnavailable
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Audio file not found at: \(url.lastPathComponent)"
        case .invalidAudioFormat(let details):
            return "Invalid audio format: \(details)"
        case .bufferProcessingFailed(let reason):
            return "Audio processing failed: \(reason)"
        case .modelLoadingFailed(let model):
            return "Failed to load AI model: \(model)"
        case .coreMLInferenceFailed(let details):
            return "AI analysis failed: \(details)"
        case .unsupportedAudioFile(let format):
            return "Unsupported audio format: \(format)"
        case .insufficientAudioData:
            return "Audio file too short for analysis"
        case .analysisTimeout:
            return "Analysis timed out - please try again"
        case .permissionDenied:
            return "Microphone access required for real-time analysis"
        case .deviceResourcesUnavailable:
            return "Device resources unavailable - please close other apps"
        case .serviceUnavailable:
            return "Audio analysis service is currently unavailable"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        case .networkUnavailable:
            return "Network unavailable for analysis"
        case .unknown(let error):
            return "Unknown error occurred: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Please check if the file exists and try again."
        case .invalidAudioFormat, .unsupportedAudioFile:
            return "Try converting to MP3, AAC, or WAV format."
        case .bufferProcessingFailed, .coreMLInferenceFailed:
            return "Restart the app and try again."
        case .modelLoadingFailed:
            return "Update the app to the latest version."
        case .insufficientAudioData:
            return "Audio should be at least 10 seconds long."
        case .analysisTimeout:
            return "Check your device performance and try again."
        case .permissionDenied:
            return "Enable microphone access in Settings > Privacy."
        case .deviceResourcesUnavailable:
            return "Free up device memory and try again."
        case .serviceUnavailable:
            return "Try again later."
        case .maxRetriesExceeded:
            return "Please try again later."
        case .networkUnavailable:
            return "Check your network connection and try again."
        case .unknown:
            return "Please try again."
        }
    }
}

/// User-friendly error messages for display
struct AudioAnalysisUserError {
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    static func from(_ error: AudioAnalysisError) -> AudioAnalysisUserError {
        switch error {
        case .fileNotFound:
            return AudioAnalysisUserError(
                title: "File Not Found",
                message: "The audio file couldn't be located. It may have been moved or deleted.",
                actionTitle: "Try Another File",
                action: nil
            )
        case .invalidAudioFormat, .unsupportedAudioFile:
            return AudioAnalysisUserError(
                title: "Unsupported Format",
                message: "This audio format isn't supported. Please try a different file.",
                actionTitle: "Learn More",
                action: nil
            )
        case .permissionDenied:
            return AudioAnalysisUserError(
                title: "Microphone Access Needed",
                message: "Real-time mood detection requires microphone access.",
                actionTitle: "Open Settings",
                action: { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
            )
        case .deviceResourcesUnavailable:
            return AudioAnalysisUserError(
                title: "Device Busy",
                message: "Your device is running low on resources. Close other apps and try again.",
                actionTitle: "Retry",
                action: nil
            )
        default:
            return AudioAnalysisUserError(
                title: "Analysis Failed",
                message: error.localizedDescription ?? "An unexpected error occurred.",
                actionTitle: "Retry",
                action: nil
            )
        }
    }
}

// We don't need a legacy model anymore, using the proper AudioFeatures model instead

// MARK: - AI Errors
enum AIError: Error, LocalizedError {
    case audioProcessingFailed(String)
    case invalidAudioFile
    case insufficientData

    var errorDescription: String? {
        switch self {
        case .audioProcessingFailed(let reason):
            return "Audio processing failed: \(reason)"
        case .invalidAudioFile:
            return "Invalid or corrupted audio file"
        case .insufficientData:
            return "Insufficient audio data for analysis"
        }
    }
}

/// Enhanced service for analyzing audio files with comprehensive error handling
class AudioAnalysisService: ObservableObject {
    // MARK: - Properties
    
    @Published private(set) var isAnalyzing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var currentFeatures: AudioFeatures?
    @Published private(set) var analysisHistory: [URL: AudioFeatures] = [:]
    @Published private(set) var performanceReport: String = ""
    
    private let audioQueue = DispatchQueue(label: "com.aimixtapes.audioanalysis", qos: .userInitiated)
    private let analysisBufferSize = 4096
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var analysisCancel: AnyCancellable?
    private let logger = Logger(subsystem: "com.aimixtapes", category: "AudioAnalysis")
    
    // FFT processing
    private lazy var fftProcessor = FFTProcessor(maxFrameSize: analysisBufferSize)
    
    // Buffer management
    private var bufferPool: [AVAudioPCMBuffer] = []
    private let maxBufferPoolSize = 5
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    
    // Performance monitoring
    private var performanceMetrics = PerformanceMetrics()
    private var processStartTime: Date?
    private var memorySamples: [Int] = []
    
    // MARK: - Public Interface
    
    /// Analyze audio file with robust error handling and progress updates
    /// - Parameters:
    ///   - url: URL of the audio file
    ///   - options: Analysis options
    /// - Returns: Publisher with analysis results or error
    func analyzeAudio(at url: URL, options: AnalysisOptions = .default) -> AnyPublisher<AudioFeatures, Error> {
        Deferred {
            Future { [weak self] promise in
                guard let self = self else {
                    promise(.failure(AudioAnalysisError.serviceUnavailable))
                    return
                }
                
                self.audioQueue.async {
                    self.performAnalysis(url: url, options: options, promise: promise)
                }
            }
        }
        .handleEvents(
            receiveSubscription: { [weak self] _ in
                self?.isAnalyzing = true
                self?.processStartTime = Date()
                self?.progress = 0
            },
            receiveCompletion: { [weak self] _ in
                self?.isAnalyzing = false
                self?.cleanup()
                self?.updatePerformanceReport()
            },
            receiveCancel: { [weak self] in
                self?.cancelAnalysis()
            }
        )
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// Analyze a short audio segment for real-time processing
    /// - Parameter buffer: Audio buffer to analyze
    /// - Returns: Extracted audio features
    func analyzeAudioBuffer(_ buffer: AVAudioPCMBuffer) -> AudioFeatures? {
        guard !isAnalyzing else { return nil }
        
        // Process with FFT
        guard let spectralFeatures = fftProcessor.analyzeSpectralFeatures(buffer) else {
            return nil
        }
        
        // Create audio features from spectral features
        let features = AudioFeatures.from(spectralFeatures: spectralFeatures)
        
        // Update current features
        DispatchQueue.main.async {
            self.currentFeatures = features
        }
        
        return features
    }
    
    /// Cancels any ongoing analysis
    func cancelCurrentAnalysis() {
        cancelAnalysis()
    }
    
    /// Returns performance statistics
    func getPerformanceStatistics() -> String {
        return performanceMetrics.generateReport()
    }
    
    // MARK: - Private Implementation
    
    private func performAnalysis(url: URL, options: AnalysisOptions, promise: @escaping (Result<AudioFeatures, Error>) -> Void) {
        var retryCount = 0
        
        func retry() {
            guard retryCount < maxRetries else {
                promise(.failure(AudioAnalysisError.maxRetriesExceeded))
                return
            }
            
            retryCount += 1
            logger.info("Retrying analysis (attempt \(retryCount)/\(maxRetries))")
            
            DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay) {
                self.performAnalysis(url: url, options: options, promise: promise)
            }
        }
        
        do {
            // Check if we already have processed this file
            if let cachedFeatures = analysisHistory[url] {
                logger.info("Using cached analysis for \(url.lastPathComponent)")
                promise(.success(cachedFeatures))
                return
            }
            
            // Setup audio session
            try setupAudioSession()
            
            // Load and validate audio file
            guard let audioFile = try? loadAudioFile(url: url) else {
                throw AudioAnalysisError.fileNotFound(url)
            }
            
            // Process audio in chunks
            let features = try processAudioChunks(audioFile: audioFile, options: options)
            
            // Cache the results
            DispatchQueue.main.async {
                self.analysisHistory[url] = features
                self.currentFeatures = features
            }
            
            // Log success metrics
            let processingTime = processStartTime != nil ? Date().timeIntervalSince(processStartTime!) : 0
            logSuccessMetrics(audioFile: audioFile, processingTime: processingTime)
            
            promise(.success(features))
        } catch let error as AudioAnalysisError {
            handleAnalysisError(error, retryBlock: retry, promise: promise)
        } catch {
            promise(.failure(AudioAnalysisError.unknown(error)))
        }
    }
    
    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }
    
    private func loadAudioFile(url: URL) throws -> AVAudioFile {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioAnalysisError.fileNotFound(url)
        }
        
        guard let file = try? AVAudioFile(forReading: url) else {
            throw AudioAnalysisError.invalidAudioFormat("Could not read audio file format")
        }
        
        self.audioFile = file
        return file
    }
    
    private func processAudioChunks(audioFile: AVAudioFile, options: AnalysisOptions) throws -> AudioFeatures {
        let format = audioFile.processingFormat
        let channelCount = format.channelCount
        
        // Configure buffer
        let bufferSize = AVAudioFrameCount(analysisBufferSize)
        let buffer = getOrCreateBuffer(with: format, frameCapacity: bufferSize)
        
        var totalFrames: AVAudioFrameCount = 0
        let frameCount = audioFile.length
        
        // Initialize result containers
        var allSpectralFeatures: [SpectralFeatures] = []
        var energyValues: [Float] = []
        var peakValues: [Float] = []
        
        // Check if we have enough audio to analyze
        if frameCount < bufferSize {
            throw AudioAnalysisError.insufficientAudioData
        }
        
        // Process audio in chunks
        while totalFrames < frameCount {
            try autoreleasepool {
                // Reset buffer
                buffer.frameLength = 0
                
                // Read chunk
                do {
                    try audioFile.read(into: buffer)
                } catch {
                    throw AudioAnalysisError.bufferProcessingFailed("Failed to read audio chunk: \(error.localizedDescription)")
                }
                
                // Process spectral features
                if options.contains(.spectralAnalysis) {
                    if let features = fftProcessor.analyzeSpectralFeatures(buffer) {
                        allSpectralFeatures.append(features)
                    }
                }
                
                // Process energy features
                if let channelData = buffer.floatChannelData {
                    let rms = processAudioRMS(channelData, channelCount: channelCount, frameLength: buffer.frameLength)
                    energyValues.append(rms)
                    
                    // Find peak value
                    var peak: Float = 0
                    vDSP_maxv(channelData[0], 1, &peak, vDSP_Length(buffer.frameLength))
                    peakValues.append(peak)
                }
                
                // Track memory usage
                sampleMemoryUsage()
                
                // Update progress
                totalFrames += buffer.frameLength
                updateProgress(Double(totalFrames) / Double(frameCount))
            }
        }
        
        // Return buffer to pool
        returnBufferToPool(buffer)
        
        // Combine all features into final result
        return createFinalFeatures(
            spectralFeatures: allSpectralFeatures,
            energyValues: energyValues,
            peakValues: peakValues,
            tempo: options.contains(.tempoAnalysis) ? estimateTempo(energyValues: energyValues, sampleRate: Float(format.sampleRate), bufferSize: Int(bufferSize)) : nil
        )
    }
    
    private func processAudioRMS(_ channelData: UnsafePointer<UnsafeMutablePointer<Float>>, channelCount: AVAudioChannelCount, frameLength: AVAudioFrameCount) -> Float {
        // Process audio data using vDSP for efficiency
        var rms: Float = 0
        vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(frameLength))
        return rms
    }
    
    private func estimateTempo(energyValues: [Float], sampleRate: Float, bufferSize: Int) -> Float? {
        // Simple onset detection and tempo estimation
        guard energyValues.count > 1 else { return nil }
        
        // Calculate energy differences to detect onsets
        var diffs: [Float] = []
        for i in 1..<energyValues.count {
            diffs.append(max(0, energyValues[i] - energyValues[i-1]))
        }
        
        // Apply threshold to find significant onsets
        let mean = diffs.reduce(0, +) / Float(diffs.count)
        let threshold = mean * 1.5
        var onsets: [Int] = []
        
        for i in 0..<diffs.count {
            if diffs[i] > threshold {
                onsets.append(i)
            }
        }
        
        // Calculate inter-onset intervals
        guard onsets.count > 1 else { return 120.0 } // Default tempo if we can't detect
        
        var intervals: [Int] = []
        for i in 1..<onsets.count {
            intervals.append(onsets[i] - onsets[i-1])
        }
        
        // Calculate average interval in frames
        let avgInterval = Float(intervals.reduce(0, +)) / Float(intervals.count)
        
        // Convert to tempo (beats per minute)
        // frames per beat / (frames per second) * 60 seconds = beats per minute
        let framesPerSecond = sampleRate / Float(bufferSize)
        let tempo = (framesPerSecond * 60.0) / avgInterval
        
        return max(min(tempo, 240.0), 40.0) // Clamp to reasonable range
    }
    
    private func createFinalFeatures(spectralFeatures: [SpectralFeatures], energyValues: [Float], peakValues: [Float], tempo: Float?) -> AudioFeatures {
        // Calculate averages from all the gathered data
        let avgEnergy = energyValues.reduce(0, +) / Float(max(1, energyValues.count))
        let peakEnergy = peakValues.max() ?? 0
        
        // Create a combined spectral features set with averaged values
        var combinedSpectralFeatures = SpectralFeatures()
        
        if !spectralFeatures.isEmpty {
            // Calculate spectral averages
            combinedSpectralFeatures.centroid = spectralFeatures.reduce(0) { $0 + $1.centroid } / Float(spectralFeatures.count)
            combinedSpectralFeatures.spread = spectralFeatures.reduce(0) { $0 + $1.spread } / Float(spectralFeatures.count)
            combinedSpectralFeatures.rolloff = spectralFeatures.reduce(0) { $0 + $1.rolloff } / Float(spectralFeatures.count)
            combinedSpectralFeatures.flux = spectralFeatures.reduce(0) { $0 + $1.flux } / Float(spectralFeatures.count)
            combinedSpectralFeatures.bassEnergy = spectralFeatures.reduce(0) { $0 + $1.bassEnergy } / Float(spectralFeatures.count)
            combinedSpectralFeatures.midEnergy = spectralFeatures.reduce(0) { $0 + $1.midEnergy } / Float(spectralFeatures.count)
            combinedSpectralFeatures.trebleEnergy = spectralFeatures.reduce(0) { $0 + $1.trebleEnergy } / Float(spectralFeatures.count)
            combinedSpectralFeatures.brightness = spectralFeatures.reduce(0) { $0 + $1.brightness } / Float(spectralFeatures.count)
            combinedSpectralFeatures.flatness = spectralFeatures.reduce(0) { $0 + $1.flatness } / Float(spectralFeatures.count)
            combinedSpectralFeatures.crest = spectralFeatures.reduce(0) { $0 + $1.crest } / Float(spectralFeatures.count)
            combinedSpectralFeatures.irregularity = spectralFeatures.reduce(0) { $0 + $1.irregularity } / Float(spectralFeatures.count)
            combinedSpectralFeatures.skewness = spectralFeatures.reduce(0) { $0 + $1.skewness } / Float(spectralFeatures.count)
            combinedSpectralFeatures.kurtosis = spectralFeatures.reduce(0) { $0 + $1.kurtosis } / Float(spectralFeatures.count)
            
            // Set estimated tempo if we calculated it
            if let calculatedTempo = tempo {
                combinedSpectralFeatures.estimatedTempo = calculatedTempo
            }
        }
        
        // Estimate perceptual features
        let valence = estimateValence(
            centroid: combinedSpectralFeatures.centroid,
            spread: combinedSpectralFeatures.spread,
            bassEnergy: combinedSpectralFeatures.bassEnergy,
            midEnergy: combinedSpectralFeatures.midEnergy,
            trebleEnergy: combinedSpectralFeatures.trebleEnergy
        )
        
        let danceability = estimateDanceability(
            tempo: tempo ?? 120.0,
            flux: combinedSpectralFeatures.flux,
            energy: avgEnergy
        )
        
        // Create audio features using the full model
        var features = AudioFeatures()
        features.energy = avgEnergy
        features.valence = valence
        features.tempo = tempo ?? 120.0
        features.danceability = danceability
        features.acousticness = estimateAcousticness(centroid: combinedSpectralFeatures.centroid, spread: combinedSpectralFeatures.spread)
        features.instrumentalness = 0.5 // Default value, would need ML for better estimate
        features.speechiness = 0.1 // Default value, would need ML for better estimate
        features.liveness = 0.1 // Default value, would need ML for better estimate
        
        // Set spectral features
        features.spectralFeatures = combinedSpectralFeatures
        
        // Add rhythm features if available
        if tempo != nil {
            features.rhythmFeatures = [
                "tempo": tempo!,
                "beatStrength": combinedSpectralFeatures.flux * 0.8, // Simple approximation
                "rhythmicComplexity": combinedSpectralFeatures.irregularity * 0.5
            ]
        }
        
        return features
    }
    
    private func estimateValence(centroid: Float, spread: Float, bassEnergy: Float, midEnergy: Float, trebleEnergy: Float) -> Float {
        // Higher centroid and treble often correlate with more positive valence
        let centroidFactor = normalizeToRange(centroid, min: 500, max: 5000) * 0.4
        
        // Bass energy can contribute to both positive and negative valence
        let bassFactor = bassEnergy * 0.2
        
        // Treble often increases perceived positivity
        let trebleFactor = trebleEnergy * 0.4
        
        // Combine factors
        let combinedValence = centroidFactor + bassFactor + trebleFactor
        
        // Normalize to 0-1 range
        return min(1.0, max(0.0, combinedValence))
    }
    
    private func estimateDanceability(tempo: Float, flux: Float, energy: Float) -> Float {
        // Tempo factor - danceability peaks around 100-130 BPM
        let tempoFactor = 1.0 - abs((tempo - 120.0) / 60.0)
        
        // Flux factor - regular changes in spectrum are more danceable
        let fluxFactor = min(1.0, flux * 5.0)
        
        // Energy factor - more energy is generally more danceable
        let energyFactor = min(1.0, energy * 2.0)
        
        // Combine factors
        let combinedDanceability = (tempoFactor * 0.4) + (fluxFactor * 0.3) + (energyFactor * 0.3)
        
        // Normalize to 0-1 range
        return min(1.0, max(0.0, combinedDanceability))
    }
    
    private func estimateAcousticness(centroid: Float, spread: Float) -> Float {
        // Lower centroid often indicates more acoustic sources
        let centroidFactor = 1.0 - normalizeToRange(centroid, min: 500, max: 5000)
        
        // Higher spread often indicates more harmonic content (acoustic)
        let spreadFactor = normalizeToRange(spread, min: 500, max: 2000)
        
        // Combined estimate
        return min(1.0, max(0.0, (centroidFactor * 0.6) + (spreadFactor * 0.4)))
    }
    
    private func normalizeToRange(_ value: Float, min: Float, max: Float) -> Float {
        return (value - min) / (max - min)
    }
    
    private func updateProgress(_ progress: Double) {
        DispatchQueue.main.async {
            self.progress = min(max(progress, 0), 1)
        }
    }
    
    private func cancelAnalysis() {
        audioQueue.async { [weak self] in
            self?.cleanup()
        }
    }
    
    private func cleanup() {
        audioFile = nil
        audioEngine?.stop()
        audioEngine = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Buffer Management
    
    private func getOrCreateBuffer(with format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> AVAudioPCMBuffer {
        if let buffer = bufferPool.first {
            bufferPool.removeFirst()
            return buffer
        }
        
        return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)!
    }
    
    private func returnBufferToPool(_ buffer: AVAudioPCMBuffer) {
        if bufferPool.count < maxBufferPoolSize {
            buffer.frameLength = 0
            bufferPool.append(buffer)
        }
    }
    
    // MARK: - Performance Monitoring
    
    private func sampleMemoryUsage() {
        let memoryUsage = getMemoryUsage()
        memorySamples.append(memoryUsage)
    }
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
    
    private func updatePerformanceReport() {
        DispatchQueue.main.async {
            self.performanceReport = self.performanceMetrics.generateReport()
        }
    }
    
    // MARK: - Error Handling
    
    private func handleAnalysisError(_ error: AudioAnalysisError, retryBlock: @escaping () -> Void, promise: @escaping (Result<AudioFeatures, Error>) -> Void) {
        logger.error("Audio analysis error: \(error.localizedDescription)")
        
        switch error {
        case .deviceResourcesUnavailable, .networkUnavailable, .analysisTimeout:
            // These errors are retriable
            retryBlock()
        default:
            promise(.failure(error))
        }
    }
    
    private func logSuccessMetrics(audioFile: AVAudioFile, processingTime: TimeInterval) {
        // Calculate average memory usage
        let avgMemory = memorySamples.reduce(0, +) / max(1, memorySamples.count)
        memorySamples = []
        
        performanceMetrics.recordAnalysis(
            duration: audioFile.duration,
            format: audioFile.processingFormat.description,
            processingTime: processingTime,
            memoryUsed: avgMemory
        )
    }
}

// MARK: - Supporting Types

struct AnalysisOptions: OptionSet {
    let rawValue: Int
    
    static let spectralAnalysis = AnalysisOptions(rawValue: 1 << 0)
    static let tempoAnalysis = AnalysisOptions(rawValue: 1 << 1)
    static let pitchAnalysis = AnalysisOptions(rawValue: 1 << 2)
    static let loudnessAnalysis = AnalysisOptions(rawValue: 1 << 3)
    static let rhythmAnalysis = AnalysisOptions(rawValue: 1 << 4)
    static let moodAnalysis = AnalysisOptions(rawValue: 1 << 5)
    static let genreAnalysis = AnalysisOptions(rawValue: 1 << 6)
    static let harmonicAnalysis = AnalysisOptions(rawValue: 1 << 7)
    static let cachingEnabled = AnalysisOptions(rawValue: 1 << 8)
    static let highPrecision = AnalysisOptions(rawValue: 1 << 9)
    static let lowLatency = AnalysisOptions(rawValue: 1 << 10)
    
    static let quick: AnalysisOptions = [.spectralAnalysis, .loudnessAnalysis]
    static let standard: AnalysisOptions = [.spectralAnalysis, .tempoAnalysis, .loudnessAnalysis, .rhythmAnalysis, .cachingEnabled]
    static let comprehensive: AnalysisOptions = [.spectralAnalysis, .tempoAnalysis, .pitchAnalysis, .loudnessAnalysis, .rhythmAnalysis, .moodAnalysis, .harmonicAnalysis, .cachingEnabled, .highPrecision]
    
    static let `default`: AnalysisOptions = .standard
}

struct PerformanceMetrics {
    private(set) var analysisCount = 0
    private(set) var totalDuration: TimeInterval = 0
    private(set) var averageProcessingTime: TimeInterval = 0
    private(set) var memoryUsage: Int = 0
    private(set) var cpuLoad: Double = 0
    private(set) var peakMemoryUsage: Int = 0
    private var processingTimes: [TimeInterval] = []
    private let maxHistoryEntries = 20
    
    mutating func recordAnalysis(duration: TimeInterval, format: String, processingTime: TimeInterval = 0, memoryUsed: Int = 0) {
        analysisCount += 1
        totalDuration += duration
        
        // Update processing times history
        processingTimes.append(processingTime)
        if processingTimes.count > maxHistoryEntries {
            processingTimes.removeFirst()
        }
        
        // Calculate average processing time
        let total = processingTimes.reduce(0, +)
        averageProcessingTime = processingTimes.isEmpty ? 0 : total / Double(processingTimes.count)
        
        // Update memory metrics
        memoryUsage = memoryUsed
        peakMemoryUsage = max(peakMemoryUsage, memoryUsed)
        
        // Estimate CPU load based on processing time relative to audio duration
        if duration > 0 {
            cpuLoad = min(1.0, processingTime / duration)
        }
    }
    
    var isProcessingEfficient: Bool {
        return averageProcessingTime < 0.1 && cpuLoad < 0.5
    }
    
    func generateReport() -> String {
        return """
        Analysis Report:
        - Total files processed: \(analysisCount)
        - Total audio duration: \(String(format: "%.2f", totalDuration))s
        - Average processing time: \(String(format: "%.3f", averageProcessingTime))s
        - Current memory usage: \(memoryUsage / 1024) KB
        - Peak memory usage: \(peakMemoryUsage / 1024) KB
        - Estimated CPU load: \(String(format: "%.1f", cpuLoad * 100))%
        - Processing efficiency: \(isProcessingEfficient ? "Good" : "Needs optimization")
        """
    }
}

// MARK: - AVAudioFile Extension

extension AVAudioFile {
    var duration: TimeInterval {
        Double(length) / processingFormat.sampleRate
    }
}

// MARK: - AudioFeatures Extensions
extension AudioFeatures {
    /// Create AudioFeatures from SpectralFeatures
    static func from(spectralFeatures: SpectralFeatures) -> AudioFeatures {
        var features = AudioFeatures()
        
        // Copy spectral features to create a new instance
        features.spectralFeatures = spectralFeatures
        
        // Set band energies and other metrics based on spectral features
        features.energy = (spectralFeatures.bassEnergy + spectralFeatures.midEnergy + spectralFeatures.trebleEnergy) / 3.0
        features.valence = spectralFeatures.brightness * 0.5 + 0.25 // Default estimate
        features.tempo = spectralFeatures.estimatedTempo > 0 ? spectralFeatures.estimatedTempo : 120.0 // Default tempo
        features.danceability = min(1.0, spectralFeatures.flux * 2.0)
        features.acousticness = 1.0 - spectralFeatures.brightness
        
        return features
    }
    
    // Properties to match with SpectralFeatures structure to make the code cleaner
    var spectralCentroid: Float {
        get { spectralFeatures?.centroid ?? 0 }
        set { 
            if spectralFeatures == nil {
                spectralFeatures = SpectralFeatures()
            }
            spectralFeatures?.centroid = newValue 
        }
    }
    
    var spectralSpread: Float {
        get { spectralFeatures?.spread ?? 0 }
        set { 
            if spectralFeatures == nil {
                spectralFeatures = SpectralFeatures()
            }
            spectralFeatures?.spread = newValue 
        }
    }
    
    var spectralRolloff: Float {
        get { spectralFeatures?.rolloff ?? 0 }
        set { 
            if spectralFeatures == nil {
                spectralFeatures = SpectralFeatures()
            }
            spectralFeatures?.rolloff = newValue 
        }
    }
    
    var spectralFlux: Float {
        get { spectralFeatures?.flux ?? 0 }
        set { 
            if spectralFeatures == nil {
                spectralFeatures = SpectralFeatures()
            }
            spectralFeatures?.flux = newValue 
        }
    }
    
    var bassEnergy: Float {
        get { spectralFeatures?.bassEnergy ?? 0 }
        set { 
            if spectralFeatures == nil {
                spectralFeatures = SpectralFeatures()
            }
            spectralFeatures?.bassEnergy = newValue 
        }
    }
    
    var midEnergy: Float {
        get { spectralFeatures?.midEnergy ?? 0 }
        set { 
            if spectralFeatures == nil {
                spectralFeatures = SpectralFeatures()
            }
            spectralFeatures?.midEnergy = newValue 
        }
    }
    
    var trebleEnergy: Float {
        get { spectralFeatures?.trebleEnergy ?? 0 }
        set { 
            if spectralFeatures == nil {
                spectralFeatures = SpectralFeatures()
            }
            spectralFeatures?.trebleEnergy = newValue 
        }
    }
}
