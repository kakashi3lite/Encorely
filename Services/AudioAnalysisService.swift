//
//  AudioAnalysisService.swift
//  Mixtapes
//
//  Enhanced with proper memory management for audio buffers
//  Fixes ISSUE-005: Memory Management in Audio Buffers
//

import Foundation
import AVFoundation
import Accelerate
import CoreML
import Combine
import os.log
import Domain
import SwiftUI
import os.signpost

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

/// Enhanced audio analysis service with proper memory management
class AudioAnalysisService: ObservableObject {
    // Performance monitoring
    private let signposter = OSSignposter(subsystem: "com.aimixtapes", category: "AudioAnalysis")
    private static let audioProcessingInterval = OSSignpostInterval(name: "Audio Processing")
    private static let fftInterval = OSSignpostInterval(name: "FFT Analysis")
    private static let bufferInterval = OSSignpostInterval(name: "Buffer Management")
    
    // High-priority audio queue
    private let realTimeQueue = DispatchQueue(label: "com.aimixtapes.realtime",
                                            qos: .userInteractive,
                                            attributes: .concurrent)
    
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
    
    // MARK: - Audio Engine Components
    private let audioPlayerNode = AVAudioPlayerNode()
    private var audioTap: AVAudioNodeTap?
    
    // MARK: - Buffer Management
    private var audioBufferPool: AudioBufferPool
    private let bufferQueue = DispatchQueue(label: "audio.buffer.queue", qos: .userInteractive)
    private let analysisQueue = DispatchQueue(label: "audio.analysis.queue", qos: .utility)
    
    // MARK: - Memory Management
    private var isProcessing = false
    
    // MARK: - Configuration
    private let sampleRate: Double = 44100.0
    private let bufferSize: UInt32 = 1024
    private let maxBuffersInPool: Int = 10
    
    // MARK: - Publishers
    private let featuresSubject = PassthroughSubject<AudioFeatures, Never>()
    var featuresPublisher: AnyPublisher<AudioFeatures, Never> {
        featuresSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init() {
        self.audioBufferPool = AudioBufferPool(maxBuffers: maxBuffersInPool, bufferSize: bufferSize)
        setupAudioEngine()
    }
    
    deinit {
        cleanup()
    }
    
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
    
    /// Start real-time audio analysis with proper buffer management
    /// - Parameter completion: Closure to receive analyzed audio features
    /// - Throws: AudioAnalysisError if analysis cannot be started
    func startRealTimeAnalysis(completion: @escaping (AudioFeatures) -> Void) throws {
        guard !isAnalyzing else {
            throw AudioAnalysisError.serviceUnavailable
        }
        
        isAnalyzing = true
        isProcessing = true
        
        // Setup audio tap with managed buffers
        try setupAudioTap { [weak self] features in
            DispatchQueue.main.async {
                self?.currentFeatures = features
                self?.featuresSubject.send(features)
                completion(features)
            }
        }
        
        // Start audio engine
        try audioEngine.start()
        audioPlayerNode.play()
    }
    
    /// Stop real-time analysis and cleanup resources
    func stopRealTimeAnalysis() {
        isAnalyzing = false
        isProcessing = false
        
        // Stop audio engine
        audioPlayerNode.stop()
        audioEngine.stop()
        
        // Remove audio tap and cleanup buffers
        removeAudioTap()
        
        // Clean up buffer pool
        audioBufferPool.releaseAllBuffers()
    }
    
    /// Analyze a specific audio file with memory-safe processing
    /// - Parameter url: URL of the audio file
    /// - Returns: Extracted audio features
    /// - Throws: AudioAnalysisError if analysis fails
    func analyzeAudioFile(_ url: URL) async throws -> AudioFeatures {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AudioAnalysisError.serviceUnavailable)
                    return
                }
                
                do {
                    let audioFile = try AVAudioFile(forReading: url)
                    let features = try self.extractFeaturesFromFile(audioFile)
                    continuation.resume(returning: features)
                } catch {
                    continuation.resume(throwing: AudioAnalysisError.unknown(error))
                }
            }
        }
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
    
    private func extractFeaturesFromBuffer(_ buffer: AVAudioPCMBuffer) -> AudioFeatures {
        guard let channelData = buffer.floatChannelData?[0] else {
            return AudioFeatures()
        }
        
        // Get spectral features using FFT
        guard let spectralFeatures = fftProcessor.analyzeSpectralFeatures(buffer) else {
            return AudioFeatures()
        }
        
        // Calculate RMS energy
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(buffer.frameLength))
        
        // Find peak value for dynamic range
        var peak: Float = 0
        vDSP_maxv(channelData, 1, &peak, vDSP_Length(buffer.frameLength))
        
        // Convert spectral features to audio features
        var features = AudioFeatures.from(spectralFeatures: spectralFeatures)
        
        // Set energy and dynamic range
        features.energy = rms
        features.dynamicRange = 20 * log10f(peak / (rms + Float.ulpOfOne))
        
        return features
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
        
        // Process audio in chunks with managed memory
        while totalFrames < frameCount {
            try autoreleasepool {
                buffer.frameLength = 0
                
                // Read chunk
                try audioFile.read(into: buffer)
                
                // Track buffer for memory management
                trackBuffer(buffer)
                
                if let features = fftProcessor.analyzeSpectralFeatures(buffer) {
                    allSpectralFeatures.append(features)
                }
                
                // Process energy features
                if let channelData = buffer.floatChannelData {
                    var rms: Float = 0
                    vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(buffer.frameLength))
                    energyValues.append(rms)
                    
                    var peak: Float = 0
                    vDSP_maxv(channelData[0], 1, &peak, vDSP_Length(buffer.frameLength))
                    peakValues.append(peak)
                }
                
                untrackBuffer(buffer)
                totalFrames += buffer.frameLength
                updateProgress(Double(totalFrames) / Double(frameCount))
            }
        }
        
        // Return buffer to pool
        returnBufferToPool(buffer)
        
        // Combine all features
        return createFinalFeatures(
            spectralFeatures: allSpectralFeatures, 
            energyValues: energyValues,
            peakValues: peakValues,
            tempo: options.contains(.tempoAnalysis) ? 
                   estimateTempo(energyValues: energyValues, 
                               sampleRate: Float(format.sampleRate), 
                               bufferSize: Int(bufferSize)) : nil
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
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() {
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            logger.error("Failed to setup audio session: \(error.localizedDescription)")
        }
        
        // Attach nodes
        audioEngine.attach(audioPlayerNode)
        
        // Connect nodes
        let mainMixerNode = audioEngine.mainMixerNode
        audioEngine.connect(audioPlayerNode, to: mainMixerNode, format: nil)
        
        // Prepare engine
        audioEngine.prepare()
    }
    
    private func setupAudioTap(completion: @escaping (AudioFeatures) -> Void) throws {
        let inputFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
        
        // Remove existing tap
        removeAudioTap()
        
        // Install new tap with buffer management
        audioTap = audioEngine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: bufferSize,
            format: inputFormat
        ) { [weak self] (buffer, time) in
            self?.processAudioBuffer(buffer, time: time, completion: completion)
        }
    }
    
    private func removeAudioTap() {
        if audioTap != nil {
            audioEngine.mainMixerNode.removeTap(onBus: 0)
            audioTap = nil
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime, completion: @escaping (AudioFeatures) -> Void) {
        guard isAnalyzing else { return }
        
        // Get a managed buffer from pool
        guard let managedBuffer = audioBufferPool.getBuffer() else {
            logger.warning("No available buffers in pool")
            return
        }
        
        // Copy buffer data safely
        managedBuffer.copyFrom(buffer)
        
        // Process on background queue
        analysisQueue.async { [weak self] in
            guard let self = self else {
                self?.audioBufferPool.returnBuffer(managedBuffer)
                return
            }
            
            let features = self.extractFeaturesFromBuffer(managedBuffer.buffer)
            
            // Return buffer to pool
            self.audioBufferPool.returnBuffer(managedBuffer)
            
            // Deliver results on main queue
            DispatchQueue.main.async {
                completion(features)
            }
        }
    }
    
    private func extractFeaturesFromFile(_ audioFile: AVAudioFile) throws -> AudioFeatures {
        let format = audioFile.processingFormat
        let channelCount = format.channelCount
        
        // Configure buffer
        let bufferSize = AVAudioFrameCount(analysisBufferSize)
        let buffer = getOrCreateBuffer(with: format, frameCapacity: bufferSize)
        
        // Initialize result containers
        var allSpectralFeatures: [SpectralFeatures] = []
        var energyValues: [Float] = []
        var peakValues: [Float] = []
        var onsetStrengths: [Float] = []
        
        // Process audio in chunks
        var totalFrames: AVAudioFrameCount = 0
        while totalFrames < audioFile.length {
            autoreleasepool {
                // Read chunk
                try audioFile.read(into: buffer)
                
                // Process spectral features
                if let features = fftProcessor.analyzeSpectralFeatures(buffer) {
                    allSpectralFeatures.append(features)
                }
                
                // Process energy and onset features
                if let channelData = buffer.floatChannelData?[0] {
                    // RMS energy
                    var rms: Float = 0
                    vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(buffer.frameLength))
                    energyValues.append(rms)
                    
                    // Peak detection
                    var peak: Float = 0
                    vDSP_maxv(channelData, 1, &peak, vDSP_Length(buffer.frameLength))
                    peakValues.append(peak)
                    
                    // Onset detection
                    let onsetStrength = calculateOnsetStrength(channelData, frameLength: Int(buffer.frameLength))
                    onsetStrengths.append(onsetStrength)
                }
                
                totalFrames += buffer.frameLength
            }
        }
        
        // Create final features
        return createFinalFeatures(
            spectralFeatures: allSpectralFeatures,
            energyValues: energyValues,
            peakValues: peakValues,
            tempo: estimateTempo(from: onsetStrengths, sampleRate: format.sampleRate)
        )
    }
    
    private func calculateOnsetStrength(_ samples: UnsafePointer<Float>, frameLength: Int) -> Float {
        var hfc: Float = 0  // High Frequency Content
        
        // Calculate weighted sum of spectrum magnitudes
        for i in 0..<frameLength/2 {
            let weight = Float(i)  // Linear weighting by frequency bin
            let magnitude = samples[i]
            hfc += weight * magnitude * magnitude
        }
        
        return hfc
    }
    
    private func estimateTempo(from onsetStrengths: [Float], sampleRate: Double) -> Float {
        // Find peaks in onset strength signal
        var peaks: [Int] = []
        for i in 1..<onsetStrengths.count-1 {
            if onsetStrengths[i] > onsetStrengths[i-1] && onsetStrengths[i] > onsetStrengths[i+1] {
                peaks.append(i)
            }
        }
        
        // Calculate inter-onset intervals
        var intervals: [Int] = []
        for i in 1..<peaks.count {
            intervals.append(peaks[i] - peaks[i-1])
        }
        
        // Convert to tempo using most common interval
        if let mostCommonInterval = intervals.mostCommon {
            let framesPerSecond = Float(sampleRate) / Float(analysisBufferSize)
            let tempo = (framesPerSecond * 60.0) / Float(mostCommonInterval)
            return max(min(tempo, 240.0), 40.0) // Clamp to reasonable range
        }
        
        return 120.0 // Default tempo if detection fails
    }
    
    private func convertToAudioFeatures(from spectralFeatures: SpectralFeatures) -> AudioFeatures {
        // Calculate core features
        let energy = calculateEnergy(
            bassEnergy: spectralFeatures.bassEnergy,
            midEnergy: spectralFeatures.midEnergy,
            trebleEnergy: spectralFeatures.trebleEnergy,
            brightness: spectralFeatures.brightness
        )
        
        let valence = calculateValence(
            brightness: spectralFeatures.brightness,
            harmonicRatio: spectralFeatures.harmonicRatio,
            spectralContrast: spectralFeatures.spectralContrast,
            energy: energy
        )
        
        // Create AudioFeatures instance with calculated values
        var features = AudioFeatures()
        features.tempo = spectralFeatures.estimatedTempo > 0 ? spectralFeatures.estimatedTempo : 120.0
        features.energy = energy
        features.valence = valence
        features.danceability = calculateDanceability(
            tempo: features.tempo,
            energy: energy,
            flux: spectralFeatures.flux
        )
        features.acousticness = calculateAcousticness(
            centroid: spectralFeatures.centroid,
            spread: spectralFeatures.spread,
            flatness: spectralFeatures.flatness
        )
        features.instrumentalness = calculateInstrumentalness(
            harmonicRatio: spectralFeatures.harmonicRatio,
            spectralContrast: spectralFeatures.spectralContrast
        )
        features.speechiness = calculateSpeechiness(
            zeroCrossingRate: spectralFeatures.zeroCrossingRate,
            spectralFlatness: spectralFeatures.flatness
        )
        features.liveness = calculateLiveness(
            dynamicRange: spectralFeatures.dynamicRange,
            crest: spectralFeatures.crest
        )
        
        return features
    }
    
    private func calculateEnergy(bassEnergy: Float, midEnergy: Float, trebleEnergy: Float, brightness: Float) -> Float {
        let weightedSum = bassEnergy * 0.3 + midEnergy * 0.5 + trebleEnergy * 0.2
        return min(1.0, weightedSum * (1.0 + brightness * 0.2))
    }
    
    private func calculateValence(brightness: Float, harmonicRatio: Float, spectralContrast: Float, energy: Float) -> Float {
        return min(1.0, (
            brightness * 0.3 +
            harmonicRatio * 0.3 +
            spectralContrast * 0.2 +
            energy * 0.2
        ))
    }
    
    private func calculateDanceability(tempo: Float, energy: Float, flux: Float) -> Float {
        let tempoFactor = 1.0 - abs(tempo - 120.0) / 120.0 // Peak at 120 BPM
        return min(1.0, (tempoFactor * 0.4 + energy * 0.3 + flux * 0.3))
    }
    
    private func calculateAcousticness(centroid: Float, spread: Float, flatness: Float) -> Float {
        // Lower centroid and spread, higher flatness suggest acoustic sound
        let centroidFactor = max(0, 1.0 - (centroid / 5000.0))
        let spreadFactor = max(0, 1.0 - (spread / 2000.0))
        return min(1.0, (centroidFactor * 0.4 + spreadFactor * 0.3 + flatness * 0.3))
    }
    
    private func calculateInstrumentalness(harmonicRatio: Float, spectralContrast: Float) -> Float {
        return min(1.0, (harmonicRatio * 0.6 + spectralContrast * 0.4))
    }
    
    private func calculateSpeechiness(zeroCrossingRate: Float, spectralFlatness: Float) -> Float {
        // Higher zero-crossing rate and spectral flatness suggest speech
        return min(1.0, (zeroCrossingRate * 0.6 + spectralFlatness * 0.4))
    }
    
    private func calculateLiveness(dynamicRange: Float, crest: Float) -> Float {
        // Higher dynamic range and crest factor suggest live recording
        return min(1.0, (dynamicRange * 0.5 + crest * 0.5))
    }
}

extension Array where Element == Int {
    var mostCommon: Element? {
        var counts = [Element: Int]()
        self.forEach { counts[$0, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
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
