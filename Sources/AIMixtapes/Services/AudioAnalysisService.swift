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
import Domain

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

// MARK: - Audio Features Model
struct AudioFeatures: Codable {
    let tempo: Float
    let energy: Float
    let spectralCentroid: Float
    let valence: Float
    let danceability: Float
    let acousticness: Float
    let instrumentalness: Float
    let speechiness: Float
    let liveness: Float
    
    mutating func updateWith(rms: Float) {
        // Update features with new data
    }
}

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
    
    // Buffer management
    private let audioBufferPool: AudioBufferPool
    private let bufferQueue = DispatchQueue(label: "audio.buffer.queue", qos: .userInteractive)
    private let analysisQueue = DispatchQueue(label: "audio.analysis.queue", qos: .utility)
    private var activeBuffers = Set<ManagedAudioBuffer>()
    private let bufferLock = NSLock()
    
    // Configuration 
    private let sampleRate: Double = 44100.0
    private let bufferSize: UInt32 = 4096
    private let maxBuffersInPool: Int = 10
    
    // Memory monitoring
    private var totalMemoryUsage: Int = 0
    private let maxMemoryUsage = 50 * 1024 * 1024 // 50MB
    private var memorySamples: [Int] = []
    private let maxMemorySamples = 20
    private var processStartTime: Date?
    private var lastCleanupTime: Date?
    private let cleanupInterval: TimeInterval = 5.0
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    
    // Performance monitoring
    private var performanceMetrics = PerformanceMetrics()
    
    // MARK: - Initialization
    
    init() {
        self.audioBufferPool = AudioBufferPool(maxBuffers: maxBuffersInPool, bufferSize: bufferSize)
        setupAudioEngine()
        setupMemoryMonitoring()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup
    
    private func setupMemoryMonitoring() {
        // Start periodic memory monitoring
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkMemoryPressure()
        }
        RunLoop.main.add(timer, forMode: .common)
    }
    
    // MARK: - Memory Management
    
    private func checkMemoryPressure() {
        let currentMemory = totalMemoryUsage
        
        // Add to samples for tracking
        if memorySamples.count >= maxMemorySamples {
            memorySamples.removeFirst()
        }
        memorySamples.append(currentMemory)
        
        // Calculate pressure level
        let pressure = Double(currentMemory) / Double(maxMemoryUsage)
        
        if pressure > 0.9 {
            logger.warning("Critical memory pressure: \(pressure * 100, privacy: .public)%")
            performEmergencyCleanup()
        } else if pressure > 0.8 {
            logger.warning("High memory pressure: \(pressure * 100, privacy: .public)%")
            performGradualCleanup()
        } else if pressure > 0.7 {
            if shouldPerformRoutineCleanup() {
                performRoutineCleanup()
            }
        }
    }
    
    private func shouldPerformRoutineCleanup() -> Bool {
        guard let lastCleanup = lastCleanupTime else { return true }
        return Date().timeIntervalSince(lastCleanup) >= cleanupInterval
    }
    
    private func performRoutineCleanup() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        // Remove old buffers
        let oldBuffers = activeBuffers.filter { $0.idleTime > 30 }
        for buffer in oldBuffers {
            untrackBuffer(buffer)
        }
        
        lastCleanupTime = Date()
    }
    
    private func performGradualCleanup() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        // Sort buffers by idle time
        let sortedBuffers = activeBuffers.sorted { $0.idleTime > $1.idleTime }
        
        // Remove half of the oldest buffers
        let removeCount = sortedBuffers.count / 2
        for buffer in sortedBuffers.prefix(removeCount) {
            untrackBuffer(buffer)
        }
        
        // Reduce pool size
        audioBufferPool.reducePoolSize()
        
        lastCleanupTime = Date()
    }
    
    private func performEmergencyCleanup() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        // Clear all buffers
        activeBuffers.forEach { untrackBuffer($0) }
        activeBuffers.removeAll()
        
        // Reset buffer pool
        audioBufferPool.releaseAllBuffers()
        
        totalMemoryUsage = 0
        lastCleanupTime = Date()
        
        // Force garbage collection
        autoreleasepool {
            URLCache.shared.removeAllCachedResponses()
        }
    }
    
    private func trackBuffer(_ buffer: ManagedAudioBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        let memoryDelta = buffer.memorySize
        if totalMemoryUsage + memoryDelta > maxMemoryUsage {
            handleHighMemoryUsage()
        }
        
        activeBuffers.insert(buffer)
        totalMemoryUsage += memoryDelta
    }
    
    private func untrackBuffer(_ buffer: ManagedAudioBuffer) {
        if activeBuffers.remove(buffer) != nil {
            totalMemoryUsage -= buffer.memorySize
            audioBufferPool.returnBuffer(buffer)
        }
    }
    
    private func handleHighMemoryUsage() {
        logger.warning("Handling high memory usage: \(totalMemoryUsage / 1024 / 1024, privacy: .public) MB")
        let targetUsage = maxMemoryUsage * 3/4
        
        // Remove oldest buffers until we're under target
        let sortedBuffers = activeBuffers.sorted { $0.idleTime > $1.idleTime }
        for buffer in sortedBuffers {
            if totalMemoryUsage <= targetUsage {
                break
            }
            untrackBuffer(buffer)
        }
        
        // If still too high, perform emergency cleanup
        if totalMemoryUsage > targetUsage {
            performEmergencyCleanup()
        }
    }
    
    /// Complete cleanup of all resources
    private func cleanup() {
        // Stop audio engine if running
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
            audioEngine = nil
        }
        
        // Release audio file
        audioFile = nil
        
        // Clean up buffers
        audioBufferPool.releaseAllBuffers()
        
        // Release any analysis cancellables
        analysisCancel?.cancel()
        analysisCancel = nil
        
        // Log memory recovery
        logger.info("Cleanup complete, freed all audio resources")
    }
    
    /// Sample current memory usage for performance tracking
    private func sampleMemoryUsage() {
        if memorySamples.count >= 100 {
            memorySamples.removeFirst()
        }
        memorySamples.append(totalMemoryUsage)
    }
    
    /// Update performance report with memory usage statistics
    private func updatePerformanceReport() {
        guard !memorySamples.isEmpty else { return }
        
        let avgMemory = memorySamples.reduce(0, +) / memorySamples.count
        let peakMemory = memorySamples.max() ?? 0
        
        let processingTime = processStartTime != nil ? Date().timeIntervalSince(processStartTime!) : 0
        
        performanceReport = """
        Processing time: \(String(format: "%.2f", processingTime))s
        Average memory: \(avgMemory / 1024 / 1024)MB
        Peak memory: \(peakMemory / 1024 / 1024)MB
        Buffer pool size: \(audioBufferPool.currentPoolSize)/\(maxBuffersInPool)
        """
        
        logger.info("Performance: \(self.performanceReport, privacy: .public)")
    }
    
    /// Updates progress and publishes to UI
    private func updateProgress(_ newProgress: Double) {
        // Ensure progress is in range 0...1
        let boundedProgress = min(1.0, max(0.0, newProgress))
        
        // Update on main thread
        DispatchQueue.main.async {
            self.progress = boundedProgress
        }
        
        // Log at regular intervals
        if Int(boundedProgress * 10) != Int(self.progress * 10) {
            logger.info("Analysis progress: \(Int(boundedProgress * 100), privacy: .public)%")
        }
    }
    
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
        
        // Track buffer for memory management
        trackBuffer(buffer)
        
        // Process with FFT
        guard let spectralFeatures = fftProcessor.analyzeSpectralFeatures(buffer) else {
            untrackBuffer(buffer)
            return nil
        }
        
        // Create audio features from spectral features
        let features = convertToAudioFeatures(from: spectralFeatures)
        
        // Untrack buffer when done
        untrackBuffer(buffer)
        
        // Update current features
        DispatchQueue.main.async {
            self.currentFeatures = features
        }
        
        return features
    }
    
    /// Cancels any ongoing analysis
    private func cancelAnalysis() {
        logger.info("Analysis operation cancelled")
        
        // Cancel any running operations
        analysisCancel?.cancel()
        analysisCancel = nil
        
        // Stop audio engine if running
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
        }
        
        // Set analyzing flag to false
        DispatchQueue.main.async {
            self.isAnalyzing = false
            self.progress = 0
        }
        
        // Clean up resources
        cleanup()
    }
    
    /// Cancels any ongoing analysis and cleans up resources
    private func cancelAnalysis() {
        logger.info("Analysis operation cancelled")
        
        // Cancel any running operations
        analysisCancel?.cancel()
        analysisCancel = nil
        
        // Stop audio engine if running
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
        }
        
        // Set analyzing flag to false
        DispatchQueue.main.async {
            self.isAnalyzing = false
            self.progress = 0
        }
        
        // Clean up resources
        cleanup()
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
        guard let file = try? AVAudioFile(forReading: url) else {
            throw AudioAnalysisError.fileNotFound(url)
        }
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
                
                // Track buffer for memory management
                trackBuffer(buffer)
                
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
                
                // Untrack buffer when done with this chunk
                untrackBuffer(buffer)
                
                // Track memory usage
                sampleMemoryUsage()
                
                // Update progress
                totalFrames += buffer.frameLength
                updateProgress(Double(totalFrames) / Double(frameCount))
            }
        }
        
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
        
        return convertToAudioFeatures(from: combinedSpectralFeatures, withEnergy: avgEnergy, tempo: tempo)
    }
    
    private func convertToAudioFeatures(from spectralFeatures: SpectralFeatures) -> AudioFeatures {
        // Calculate core features
        let energy = calculateEnergy(
            bassEnergy: spectralFeatures.bassEnergy,
            midEnergy: spectralFeatures.midEnergy,
            trebleEnergy: spectralFeatures.trebleEnergy
        )
        
        let valence = calculateValence(
            brightness: spectralFeatures.brightness,
            harmonicRatio: spectralFeatures.harmonicRatio,
            spectralContrast: spectralFeatures.spectralContrast
        )
        
        // Create AudioFeatures instance
        return AudioFeatures(
            tempo: spectralFeatures.estimatedTempo,
            energy: energy,
            valence: valence,
            danceability: calculateDanceability(tempo: spectralFeatures.estimatedTempo, beatStrength: spectralFeatures.beatStrength),
            acousticness: 1.0 - (spectralFeatures.bassEnergy + spectralFeatures.trebleEnergy) / 2.0,
            instrumentalness: calculateInstrumentalness(spectralContrast: spectralFeatures.spectralContrast, harmonicRatio: spectralFeatures.harmonicRatio),
            speechiness: calculateSpeechiness(zeroCrossingRate: spectralFeatures.zeroCrossingRate, spectralFlatness: spectralFeatures.flatness),
            liveness: calculateLiveness(dynamicRange: spectralFeatures.dynamicRange, crest: spectralFeatures.crest),
            spectralCentroid: spectralFeatures.centroid,
            spectralRolloff: spectralFeatures.rolloff,
            zeroCrossingRate: spectralFeatures.zeroCrossingRate,
            loudness: calculateLoudness(dynamicRange: spectralFeatures.dynamicRange),
            dynamicRange: spectralFeatures.dynamicRange
        )
    }
}
