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
    
    // Background task support
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let analysisTimeout: TimeInterval = 180 // 3 minutes
    private var lastCheckpointTime: Date?
    private let checkpointInterval: TimeInterval = 30 // Save state every 30 seconds
    
    // State persistence
    private let stateQueue = DispatchQueue(label: "com.aimixtapes.state", qos: .utility)
    private let stateKey = "AudioAnalysisState"
    
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
        
        // Add to samples for memory trend analysis
        if memorySamples.count >= maxMemorySamples {
            memorySamples.removeFirst()
        }
        memorySamples.append(currentMemory)
        
        // Calculate pressure and trend
        let pressure = Double(currentMemory) / Double(maxMemoryUsage)
        let trend = calculateMemoryTrend()
        
        // Progressive cleanup based on pressure and trend
        switch (pressure, trend) {
        case (0.9..., _):
            logger.warning("Critical memory pressure: \(pressure * 100, privacy: .public)%")
            performEmergencyCleanup()
        case (0.8..., .increasing):
            logger.warning("High memory pressure with increasing trend")
            handleHighMemoryUsage()
        case (0.8..., _):
            logger.warning("High memory pressure: \(pressure * 100, privacy: .public)%")
            performGradualCleanup()
        case (0.7..., .increasing):
            if shouldPerformRoutineCleanup() {
                performRoutineCleanup()
            }
        default:
            break
        }
    }
    
    private enum MemoryTrend {
        case increasing, stable, decreasing
    }
    
    private func calculateMemoryTrend() -> MemoryTrend {
        guard memorySamples.count >= 3 else { return .stable }
        
        let recentSamples = memorySamples.suffix(3)
        let differences = zip(recentSamples.dropLast(), recentSamples.dropFirst())
            .map { $1 - $0 }
        
        let avgDifference = differences.reduce(0, +) / Int64(differences.count)
        let threshold = Int64(maxMemoryUsage) / 100 // 1% change threshold
        
        if avgDifference > threshold {
            return .increasing
        } else if avgDifference < -threshold {
            return .decreasing
        }
        return .stable
    }
    
    private func performGradualCleanup() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        let targetUsage = maxMemoryUsage * 3/4
        let sortedBuffers = activeBuffers.sorted { $0.idleTime > $1.idleTime }
        
        // Remove buffers gradually until target is reached
        for buffer in sortedBuffers {
            if totalMemoryUsage <= targetUsage {
                break
            }
            untrackBuffer(buffer)
        }
        
        // Update metrics
        lastCleanupTime = Date()
        audioBufferPool.reducePoolSize()
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
    
    // MARK: - Public Methods
    
    /// Analyze audio file with background processing support
    func analyze(url: URL, options: AnalysisOptions = .defaultOptions) -> AnyPublisher<AudioFeatures, Error> {
        Deferred {
            Future { [weak self] promise in
                guard let self = self else {
                    promise(.failure(AudioAnalysisError.serviceUnavailable))
                    return
                }
                
                // Start background task
                self.beginBackgroundTask()
                
                // Begin analysis
                self.isAnalyzing = true
                self.progress = 0
                
                // Track analysis start
                self.logger.info("Starting analysis of \(url.lastPathComponent)")
                
                do {
                    // Check for cached results
                    if let cachedFeatures = self.analysisHistory[url] {
                        self.logger.info("Using cached analysis for \(url.lastPathComponent)")
                        promise(.success(cachedFeatures))
                        self.endBackgroundTask()
                        return
                    }
                    
                    // Setup audio session
                    try self.setupAudioSession()
                    
                    // Load and validate audio file
                    guard let audioFile = try? self.loadAudioFile(url: url) else {
                        throw AudioAnalysisError.fileNotFound(url)
                    }
                    
                    // Process audio in chunks to avoid memory pressure
                    let features = try self.processAudioChunks(audioFile: audioFile, options: options)
                    
                    // Update state
                    DispatchQueue.main.async {
                        self.analysisHistory[url] = features
                        self.currentFeatures = features
                        self.progress = 1.0
                        self.isAnalyzing = false
                    }
                    
                    // Save final state
                    self.saveState()
                    
                    // End background task
                    self.endBackgroundTask()
                    
                    promise(.success(features))
                    
                } catch let error as AudioAnalysisError {
                    self.handleAnalysisError(error, url: url, promise: promise)
                } catch {
                    promise(.failure(AudioAnalysisError.unknown(error)))
                    self.endBackgroundTask()
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    private func processAudioChunks(audioFile: AVAudioFile, options: AnalysisOptions) throws -> AudioFeatures {
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        let totalChunks = Int(ceil(Double(frameCount) / Double(analysisBufferSize)))
        var processedChunks = 0
        
        // Create aggregate features
        var aggregateFeatures = AudioFeatures()
        
        // Process in chunks
        for chunkIndex in 0..<totalChunks {
            // Update progress
            let progress = Double(chunkIndex) / Double(totalChunks)
            DispatchQueue.main.async {
                self.progress = progress
            }
            
            // Check for background task expiration
            if backgroundTask == .invalid {
                throw AudioAnalysisError.deviceResourcesUnavailable
            }
            
            // Save state periodically
            checkpointIfNeeded()
            
            // Process chunk
            let chunkSize = min(analysisBufferSize, frameCount - UInt32(chunkIndex * analysisBufferSize))
            let buffer = try processChunk(size: chunkSize, offset: UInt32(chunkIndex * analysisBufferSize))
            
            // Aggregate features
            if let chunkFeatures = extractFeaturesFromBuffer(buffer) {
                aggregateFeatures.updateWith(features: chunkFeatures)
            }
            
            processedChunks += 1
        }
        
        return aggregateFeatures
    }
    
    private func handleAnalysisError(_ error: AudioAnalysisError, url: URL, promise: @escaping (Result<AudioFeatures, Error>) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isAnalyzing = false
            self.progress = 0
            
            // Log error
            self.logger.error("Analysis failed for \(url.lastPathComponent): \(error.localizedDescription)")
            
            // Attempt recovery for certain errors
            switch error {
            case .deviceResourcesUnavailable:
                // Save state and retry later
                self.saveState()
                promise(.failure(error))
                
            case .analysisTimeout:
                // Save progress and allow resume
                self.saveState()
                promise(.failure(error))
                
            default:
                promise(.failure(error))
            }
            
            self.endBackgroundTask()
        }
    }
}

// MARK: - Background Task Management

extension AudioAnalysisService {
    private func beginBackgroundTask() {
        // End any existing background task
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }
        
        // Start new background task
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.handleBackgroundTaskExpiration()
        }
        
        // Start state checkpoint timer
        lastCheckpointTime = Date()
        
        // Schedule analysis timeout
        audioQueue.asyncAfter(deadline: .now() + analysisTimeout) { [weak self] in
            self?.handleAnalysisTimeout()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            saveState()
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func handleBackgroundTaskExpiration() {
        // Save state before expiration
        saveState()
        
        // Pause analysis
        isAnalyzing = false
        
        // Notify user
        NotificationCenter.default.post(
            name: .audioServicePaused,
            object: AudioAnalysisError.deviceResourcesUnavailable
        )
        
        // End task
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func handleAnalysisTimeout() {
        guard isAnalyzing else { return }
        
        // Save final state
        saveState()
        
        // Stop analysis
        isAnalyzing = false
        
        // Notify timeout
        NotificationCenter.default.post(
            name: .audioServiceTimeout,
            object: AudioAnalysisError.analysisTimeout
        )
        
        endBackgroundTask()
    }
    
    // MARK: - State Management
    
    private func saveState() {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            
            let state = AudioAnalysisState(
                isAnalyzing: self.isAnalyzing,
                progress: self.progress,
                currentFeatures: self.currentFeatures,
                analysisHistory: self.analysisHistory
            )
            
            if let encodedState = try? JSONEncoder().encode(state) {
                UserDefaults.standard.set(encodedState, forKey: self.stateKey)
            }
            
            self.lastCheckpointTime = Date()
            self.logger.info("Analysis state saved at progress: \(self.progress)")
        }
    }
    
    private func restoreState() {
        stateQueue.async { [weak self] in
            guard let self = self,
                  let encodedState = UserDefaults.standard.data(forKey: self.stateKey),
                  let state = try? JSONDecoder().decode(AudioAnalysisState.self, from: encodedState)
            else { return }
            
            DispatchQueue.main.async {
                self.isAnalyzing = state.isAnalyzing
                self.progress = state.progress
                self.currentFeatures = state.currentFeatures
                self.analysisHistory = state.analysisHistory
                
                self.logger.info("Analysis state restored at progress: \(self.progress)")
                
                if self.isAnalyzing {
                    // Resume analysis if it was in progress
                    self.beginBackgroundTask()
                }
            }
        }
    }
    
    private func checkpointIfNeeded() {
        guard let lastCheckpoint = lastCheckpointTime,
              Date().timeIntervalSince(lastCheckpoint) >= checkpointInterval
        else { return }
        
        saveState()
    }
}
