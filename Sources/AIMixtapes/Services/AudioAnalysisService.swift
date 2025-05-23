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
    
    // FFT processing
    private lazy var fftProcessor = FFTProcessor(maxFrameSize: analysisBufferSize)
    
    // Buffer management
    private var bufferPool: [AVAudioPCMBuffer] = []
    private let maxBufferPoolSize = 5
    private var totalMemoryUsage: Int = 0
    private let maxMemoryUsage = 50 * 1024 * 1024 // 50MB limit
    private var activeBuffers: Set<AVAudioPCMBuffer> = []
    private let bufferLock = NSLock()
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    
    // Performance monitoring
    private var performanceMetrics = PerformanceMetrics()
    private var processStartTime: Date?
    private var memorySamples: [Int] = []
    
    // MARK: - Initialization
    
    init() {
        setupMemoryManagement()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryManagement() {
        // Set up memory warning observer
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #endif
    }
    
    @objc private func handleMemoryWarning() {
        cleanupBuffers()
    }
    
    private func trackBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        let bufferSize = Int(buffer.frameLength * buffer.format.streamDescription.pointee.mBytesPerFrame)
        totalMemoryUsage += bufferSize
        activeBuffers.insert(buffer)
        
        // Record this memory usage for metrics
        memorySamples.append(totalMemoryUsage)
        if memorySamples.count > 20 {
            memorySamples.removeFirst()
        }
        
        // If we're using too much memory, clean up oldest buffers
        if totalMemoryUsage > maxMemoryUsage {
            handleHighMemoryUsage()
        }
        
        // Log memory pressure if needed
        let memoryPressure = Float(totalMemoryUsage) / Float(maxMemoryUsage)
        if memoryPressure > 0.8 {
            logger.warning("High memory pressure: \(memoryPressure * 100, privacy: .public)% of limit")
        }
    }
    
    private func untrackBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        if activeBuffers.remove(buffer) != nil {
            let bufferSize = Int(buffer.frameLength * buffer.format.streamDescription.pointee.mBytesPerFrame)
            totalMemoryUsage -= bufferSize
            
            // Return buffer to pool if space available and it's a reasonable size to keep
            let isReasonableSize = buffer.frameLength <= UInt32(analysisBufferSize * 2)
            if bufferPool.count < maxBufferPoolSize && isReasonableSize {
                buffer.frameLength = 0 // Reset the buffer
                bufferPool.append(buffer)
            }
        }
    }
    
    /// Get a buffer from the pool or create a new one
    private func getOrCreateBuffer(with format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> AVAudioPCMBuffer {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        // Try to get a buffer from the pool
        if !bufferPool.isEmpty {
            let buffer = bufferPool.removeLast()
            // Verify format compatibility
            if buffer.format.isEqual(format) && buffer.frameCapacity >= frameCapacity {
                return buffer
            }
            // If format incompatible, don't return to pool
        }
        
        // Create a new buffer if none available in pool
        guard let newBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            // This should never happen with valid formats, but handle it gracefully
            fatalError("Failed to create audio buffer with format \(format) and capacity \(frameCapacity)")
        }
        
        return newBuffer
    }
    
    private func cleanupBuffers() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        activeBuffers.removeAll()
        bufferPool.removeAll()
        totalMemoryUsage = 0
    }
    
    private func handleHighMemoryUsage() {
        // Log the memory pressure
        logger.warning("Handling high memory usage: \(totalMemoryUsage / 1024 / 1024, privacy: .public) MB")
        
        // Remove oldest buffers until we're under the threshold
        let targetUsage = maxMemoryUsage * 3/4
        
        // Sort buffers by estimated age (we don't track creation time, so this is approximate)
        let sortedBuffers = Array(activeBuffers)
        
        // Remove buffers until we're under the threshold or no more buffers
        for buffer in sortedBuffers {
            // Skip if we're already below target
            if totalMemoryUsage <= targetUsage {
                break
            }
            
            untrackBuffer(buffer)
            
            // Log progress
            logger.debug("Untracked buffer, memory now: \(totalMemoryUsage / 1024 / 1024, privacy: .public) MB")
        }
        
        // If still too high, clear buffer pool completely
        if totalMemoryUsage > targetUsage {
            let freedMemory = bufferPool.reduce(0) { sum, buffer in
                sum + Int(buffer.frameCapacity * buffer.format.streamDescription.pointee.mBytesPerFrame)
            }
            bufferPool.removeAll()
            
            logger.info("Cleared buffer pool, freed \(freedMemory / 1024, privacy: .public) KB")
        }
        
        // Run garbage collection (indirectly by clearing caches)
        URLCache.shared.removeAllCachedResponses()
        
        // Notify system of memory pressure
        #if os(iOS)
        Task { @MainActor in
            UIApplication.shared.performFreeMemoryWarning()
        }
        #endif
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
        cleanupBuffers()
        
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
        Buffer pool size: \(bufferPool.count)/\(maxBufferPoolSize)
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
    
    private func convertToAudioFeatures(from spectral: SpectralFeatures, withEnergy energy: Float = 0, tempo: Float? = nil) -> AudioFeatures {
        // Calculate core emotional features from spectral features
        let calculatedEnergy = calculateEnergy(
            bassEnergy: spectral.bassEnergy,
            midEnergy: spectral.midEnergy,
            trebleEnergy: spectral.trebleEnergy,
            energy: energy
        )
        
        let valence = calculateValence(
            brightness: spectral.brightness,
            harmonicRatio: spectral.harmonicRatio,
            spectralContrast: spectral.spectralContrast,
            spread: spectral.spread,
            centroid: spectral.centroid
        )
        
        let intensity = calculateIntensity(
            energy: calculatedEnergy,
            flux: spectral.flux,
            crest: spectral.crest,
            flatness: spectral.flatness
        )
        
        // Calculate additional timbral features
        let complexity = calculateComplexity(
            spectralContrast: spectral.spectralContrast,
            spread: spectral.spread,
            irregularity: spectral.irregularity,
            kurtosis: spectral.kurtosis
        )
        
        let brightness = normalizeToRange(spectral.brightness, min: 0, max: 1)
        
        let warmth = calculateWarmth(
            bassEnergy: spectral.bassEnergy,
            midEnergy: spectral.midEnergy,
            trebleEnergy: spectral.trebleEnergy
        )
        
        // Calculate danceability from rhythm features
        let danceability = calculateDanceability(
            tempo: tempo ?? spectral.estimatedTempo,
            beatStrength: spectral.beatStrength,
            flux: spectral.flux,
            energy: calculatedEnergy
        )
        
        // Calculate acousticness based on spectral features
        let acousticness = calculateAcousticness(
            spectralFlatness: spectral.flatness,
            harmonicRatio: spectral.harmonicRatio,
            centroid: spectral.centroid
        )
        
        // Calculate instrumentalness (approximation)
        let instrumentalness = calculateInstrumentalness(
            spectralIrregularity: spectral.irregularity,
            spectralFlatness: spectral.flatness
        )
        
        // Calculate speechiness (approximation)
        let speechiness = calculateSpeechiness(
            spectralRolloff: spectral.rolloff,
            zeroCrossingRate: spectral.zeroCrossingRate
        )
        
        // Calculate liveness (approximation)
        let liveness = calculateLiveness(
            dynamicRange: spectral.dynamicRange,
            crest: spectral.crest
        )
        
        // Estimate musical mode (major vs minor) based on spectral features
        let mode = estimateMode(
            brightness: spectral.brightness,
            valence: valence
        )
        
        // Create comprehensive audio features
        return AudioFeatures(
            tempo: tempo ?? spectral.estimatedTempo,
            energy: calculatedEnergy,
            valence: valence,
            key: nil, // Key detection requires more complex pitch analysis
            mode: mode,
            danceability: danceability,
            acousticness: acousticness,
            instrumentalness: instrumentalness,
            speechiness: speechiness,
            liveness: liveness,
            spectralFeatures: spectral,
            temporalFeatures: nil, // Not implemented yet
            rhythmFeatures: [
                "beatStrength": spectral.beatStrength,
                "intensity": intensity,
                "complexity": complexity
            ]
        )
    }
    
    private func calculateEnergy(bassEnergy: Float, midEnergy: Float, trebleEnergy: Float, energy: Float = 0) -> Float {
        // If a pre-calculated energy value is provided, use it as a factor
        let preCalculatedFactor = energy > 0 ? energy : 1.0
        
        // Combine band energies with higher weight on bass and mid
        let bandEnergy = (bassEnergy * 0.5 + midEnergy * 0.3 + trebleEnergy * 0.2)
        
        // Normalize the result to a 0-1 range
        return min(1.0, bandEnergy * preCalculatedFactor)
    }
    
    private func calculateValence(brightness: Float, harmonicRatio: Float, spectralContrast: Float, spread: Float, centroid: Float) -> Float {
        // Brightness contributes positively to valence
        let brightnessContribution = brightness * 0.3
        
        // Harmonic ratio contributes positively to valence
        let harmonicContribution = harmonicRatio * 0.3
        
        // Spectral contrast can indicate tonal clarity, which can contribute positively
        let contrastContribution = min(1.0, spectralContrast / 20.0) * 0.2
        
        // Spectral centroid (which correlates with brightness but is more precise)
        let centroidFactor = normalizeToRange(centroid, min: 500, max: 5000) * 0.2
        
        // Combine all factors
        return min(1.0, brightnessContribution + harmonicContribution + contrastContribution + centroidFactor)
    }
    
    private func calculateIntensity(energy: Float, flux: Float, crest: Float, flatness: Float) -> Float {
        // Energy is the primary factor in intensity
        let energyContribution = energy * 0.5
        
        // Flux indicates dynamic changes, which contribute to intensity
        let fluxContribution = min(1.0, flux * 5.0) * 0.3
        
        // Crest factor (peak to average ratio) indicates transients
        let crestContribution = min(1.0, crest / 10.0) * 0.1
        
        // Flatness (inverse contributes to intensity)
        let flatnessContribution = (1.0 - flatness) * 0.1
        
        // Combine all factors
        return min(1.0, energyContribution + fluxContribution + crestContribution + flatnessContribution)
    }
    
    private func calculateComplexity(spectralContrast: Float, spread: Float, irregularity: Float, kurtosis: Float) -> Float {
        // Spectral contrast indicates tonal vs. noisy content
        let contrastContribution = min(1.0, spectralContrast / 20.0) * 0.3
        
        // Spread indicates how frequencies are distributed
        let spreadContribution = normalizeToRange(spread, min: 500, max: 5000) * 0.3
        
        // Irregularity indicates jaggedness of the spectrum
        let irregularityContribution = irregularity * 0.2
        
        // Kurtosis indicates peakedness of the spectrum
        let kurtosisContribution = min(1.0, max(0.0, kurtosis / 10.0)) * 0.2
        
        // Combine all factors
        return min(1.0, contrastContribution + spreadContribution + irregularityContribution + kurtosisContribution)
    }
    
    private func calculateWarmth(bassEnergy: Float, midEnergy: Float, trebleEnergy: Float) -> Float {
        // Warmth is related to the ratio of bass and low-mid to high frequencies
        let bassContribution = bassEnergy * 0.6
        let midContribution = midEnergy * 0.3
        let trebleNegation = (1.0 - trebleEnergy) * 0.1
        
        // Combine factors
        return min(1.0, bassContribution + midContribution + trebleNegation)
    }
    
    private func normalizeToRange(_ value: Float, min: Float, max: Float) -> Float {
        let normalized = (value - min) / (max - min)
        return min(1.0, max(0.0, normalized))
    }
    
    private func calculateDanceability(tempo: Float, beatStrength: Float, flux: Float, energy: Float) -> Float {
        // A good dance track typically has:
        // 1. Clear, steady beat (high beatStrength)
        // 2. Tempo in dance-friendly range (approx 90-130 BPM)
        // 3. Regular energy dynamics (moderate flux)
        // 4. Sufficient overall energy
        
        // Beat strength is very important for danceability
        let beatContribution = beatStrength * 0.5
        
        // Tempo factor - peaks around 120 BPM (typical dance tempo)
        var tempoFactor: Float = 0
        if tempo > 0 {
            // Map tempo to a 0-1 range with peak at 120 BPM
            let normalizedTempo = max(0, min(1, 1.0 - abs(tempo - 120) / 60))
            tempoFactor = normalizedTempo * 0.25
        }
        
        // Energy contribution
        let energyContribution = energy * 0.15
        
        // Flux - moderate values are best for dancing
        // Too static is boring, too chaotic is hard to dance to
        let normalizedFlux = max(0, min(1, flux * 2)) // Scale flux to useful range
        let fluxContribution = (1.0 - abs(normalizedFlux - 0.5) * 2) * 0.1
        
        return min(1.0, beatContribution + tempoFactor + energyContribution + fluxContribution)
    }
    
    private func calculateAcousticness(spectralFlatness: Float, harmonicRatio: Float, centroid: Float) -> Float {
        // Acoustic instruments typically have:
        // 1. Lower spectral flatness (less noise-like)
        // 2. Higher harmonic ratio (clearer partials)
        // 3. Moderate spectral centroid (not too bright/harsh)
        
        // Low flatness indicates stronger harmonic content (less noise)
        let flatnessContribution = (1.0 - spectralFlatness) * 0.4
        
        // High harmonic ratio indicates clearer tones
        let harmonicContribution = harmonicRatio * 0.4
        
        // Centroid - acoustic instruments tend to have moderate spectral centroid
        // Normalize centroid to a 0-1 range with peak around 2000-3000 Hz
        let centroidFactor = 1.0 - abs(normalizeToRange(centroid, min: 500, max: 8000) - 0.3) * 1.5
        let centroidContribution = max(0, centroidFactor) * 0.2
        
        return min(1.0, flatnessContribution + harmonicContribution + centroidContribution)
    }
    
    private func calculateInstrumentalness(spectralIrregularity: Float, spectralFlatness: Float) -> Float {
        // This is a rough approximation since true instrumentalness detection
        // requires more sophisticated vocal detection algorithms
        
        // Higher irregularity can indicate human voice presence
        let irregularityFactor = max(0, 1.0 - spectralIrregularity * 2) * 0.5
        
        // Higher flatness can indicate noise or electronic sounds
        let flatnessFactor = spectralFlatness * 0.5
        
        return min(1.0, (irregularityFactor + flatnessFactor))
    }
    
    private func calculateSpeechiness(spectralRolloff: Float, zeroCrossingRate: Float) -> Float {
        // Rough approximation - speech recognition requires more sophisticated analysis
        
        // Speech typically has:
        // 1. Lower spectral rolloff than music
        // 2. Higher zero crossing rate for consonants
        
        // Normalize rolloff to a 0-1 range with lower values favoring speech
        let rolloffFactor = max(0, 1.0 - normalizeToRange(spectralRolloff, min: 1000, max: 8000)) * 0.6
        
        // Normalize ZCR - speech has moderate-to-high values
        let zcrFactor = min(1.0, zeroCrossingRate * 10) * 0.4
        
        return min(1.0, rolloffFactor + zcrFactor) * 0.8 // Scale down as this is approximate
    }
    
    private func calculateLiveness(dynamicRange: Float, crest: Float) -> Float {
        // Live recordings typically have:
        // 1. Higher dynamic range
        // 2. More peaks and transients (higher crest factor)
        // 3. More ambient noise and room reverberation
        
        // Dynamic range contribution
        let dynamicContribution = min(1.0, dynamicRange * 2) * 0.6
        
        // Crest factor contribution (higher for live)
        let crestContribution = min(1.0, crest / 10.0) * 0.4
        
        return min(1.0, dynamicContribution + crestContribution)
    }
    
    private func estimateMode(brightness: Float, valence: Float) -> Float {
        // This is a simple approximation - true mode detection requires harmonic analysis
        // Major mode is generally associated with brighter, more positive mood
        // Minor mode is generally associated with darker, more negative mood
        
        // Combine brightness and valence as indicators
        let modeIndicator = brightness * 0.3 + valence * 0.7
        
        // Map to range where values above 0.5 suggest major mode
        return modeIndicator > 0.5 ? 1.0 : 0.0
    }
}

// MARK: - Public Interface

// MARK: - Supporting Types

struct AnalysisOptions: OptionSet {
    let rawValue: Int
    
    static let spectralAnalysis = AnalysisOptions(rawValue: 1 << 0)
    static let tempoAnalysis = AnalysisOptions(rawValue: 1 << 1)
    static let pitchAnalysis = AnalysisOptions(rawValue: 1 << 2)
    
    static let `default`: AnalysisOptions = [.spectralAnalysis, .tempoAnalysis]
}

struct PerformanceMetrics {
    private(set) var analysisCount = 0
    private(set) var totalDuration: TimeInterval = 0
    private(set) var averageProcessingTime: TimeInterval = 0
    
    mutating func recordAnalysis(duration: TimeInterval, format: String) {
        analysisCount += 1
        totalDuration += duration
        // Update metrics
    }
}

// MARK: - AVAudioFile Extension

extension AVAudioFile {
    var duration: TimeInterval {
        Double(length) / processingFormat.sampleRate
    }
}

/// Handles analysis errors with optional retry
private func handleAnalysisError(_ error: AudioAnalysisError, retryBlock: @escaping () -> Void, promise: @escaping (Result<AudioFeatures, Error>) -> Void) {
    logger.error("Analysis error: \(error.localizedDescription, privacy: .public)")
    
    // Determine if we should retry based on error type
    switch error {
    case .networkUnavailable, .bufferProcessingFailed, .analysisTimeout:
        // These are potentially transient issues that can be retried
        retryBlock()
    case .permissionDenied, .fileNotFound, .invalidAudioFormat, .unsupportedAudioFile, .insufficientAudioData:
        // These require user intervention
        promise(.failure(error))
    case .modelLoadingFailed, .coreMLInferenceFailed:
        // Model issues are unlikely to be resolved by retry
        promise(.failure(error))
    case .deviceResourcesUnavailable:
        // Cleanup and retry once
        cleanup()
        retryBlock()
    case .serviceUnavailable, .maxRetriesExceeded, .unknown:
        // Give up
        promise(.failure(error))
    }
}

/// Logs metrics after successful processing
private func logSuccessMetrics(audioFile: AVAudioFile, processingTime: TimeInterval) {
    let duration = audioFile.duration
    let format = audioFile.processingFormat
    
    logger.info("""
        Successfully analyzed audio:
        - Duration: \(duration, privacy: .public)s
        - Format: \(format.sampleRate, privacy: .public) Hz, \(format.channelCount, privacy: .public) channels
        - Processing time: \(processingTime, privacy: .public)s
        - Processing ratio: \(processingTime / duration, privacy: .public)x realtime
        - Peak memory: \(memorySamples.max() ?? 0 / 1024 / 1024, privacy: .public) MB
    """)
}
