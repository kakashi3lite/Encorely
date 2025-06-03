//
//  AudioProcessor.swift
//  Mixtapes
//
//  Enhanced audio processor with proper memory management
//  
//  Features:
//  - Efficient buffer pooling
//  - Adaptive processing based on system resources
//  - Batch processing support
//  - Real-time mood detection
//

import Foundation
import AVFoundation 
import Accelerate
import CoreML
import Domain

public class AudioProcessor: ObservableObject {
    // MARK: - Properties
    
    let config = AudioProcessingConfiguration.shared
    private let audioEngine = AVAudioEngine()
    private let fftProcessor: FFTProcessor
    private let audioBufferPool: AudioBufferPool
    
    // Processing queues with QoS optimization
    private let processingQueue = DispatchQueue(
        label: "audio.processing",
        qos: .userInteractive,
        attributes: .concurrent
    )
    private let analysisQueue = DispatchQueue(
        label: "audio.analysis",
        qos: .utility
    )
    
    // Memory management
    private var memoryWarningObserver: NSObjectProtocol?
    private var totalMemoryUsage: Int = 0
    private let bufferLock = NSLock()
    private var activeBuffers = Set<ManagedAudioBuffer>()
    
    // Batch processing optimization
    private var batchProcessor: AudioBatchProcessor?
    private let batchSize = 10
    private var pendingBuffers: [(ManagedAudioBuffer, Date)] = []
    
    // Performance metrics
    @Published private(set) var performanceMetrics = PerformanceMetrics()
    private var processedBufferCount: Int = 0
    private var lastMetricsUpdate = Date()
    private let metricsUpdateInterval: TimeInterval = 1.0
    
    // Feature extraction and analysis
    @Published private(set) var currentFeatures: AudioFeatures?
    @Published private(set) var detectedMood: Mood = .neutral
    @Published private(set) var isAnalyzing: Bool = false
    
    // MARK: - Initialization
    
    init() {
        self.inputNode = audioEngine.inputNode
        self.fftProcessor = FFTProcessor(maxFrameSize: config.bufferSize, sampleRate: Float(config.sampleRate))
        self.audioBufferPool = AudioBufferPool(maxBuffers: 10, bufferSize: config.bufferSize)
        
        setupMemoryManagement()
        setupPerformanceMonitoring()
        setupBatchProcessing()
    }
    
    // MARK: - Setup Methods
    
    private func setupMemoryManagement() {
        // Monitor memory warnings
        #if os(iOS)
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        #endif
        
        // Monitor memory pressure periodically
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkMemoryPressure()
        }
        
        // Listen for emergency cleanup notifications
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AudioProcessingEmergencyCleanup"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.performEmergencyCleanup()
        }
    }
    
    private func setupBatchProcessing() {
        batchProcessor = AudioBatchProcessor(
            maxBatchSize: batchSize,
            processingInterval: 0.1
        ) { [weak self] buffers in
            self?.processBatch(buffers)
        }
    }
    
    // MARK: - Memory Management
    
    private func checkMemoryPressure() {
        let pressure = Double(totalMemoryUsage) / Double(config.maxMemoryUsage)
        
        switch pressure {
        case 0.95...: // Critical
            performEmergencyCleanup()
        case 0.85...: // High
            performAggressiveCleanup()
        case 0.75...: // Moderate
            performGradualCleanup()
        default:
            break
        }
        
        updateMemoryMetrics()
    }
    
    private func performEmergencyCleanup() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        // Clear all buffers
        activeBuffers.forEach { untrackBuffer($0) }
        activeBuffers.removeAll()
        
        // Reset batch processor
        pendingBuffers.removeAll()
        batchProcessor?.reset()
        
        // Force pool cleanup
        audioBufferPool.releaseAllBuffers()
        
        totalMemoryUsage = 0
        updateMemoryMetrics()
    }
    
    private func performAggressiveCleanup() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        // Remove old buffers
        let now = Date()
        let oldBuffers = activeBuffers.filter { buffer in
            now.timeIntervalSince(buffer.lastUsedTime) > 5.0
        }
        
        oldBuffers.forEach { untrackBuffer($0) }
        
        // Clear pending batch buffers older than 2 seconds
        pendingBuffers.removeAll { 
            now.timeIntervalSince($0.1) > 2.0
        }
    }
    
    private func performGradualCleanup() {
        let targetUsage = Int(Double(config.maxMemoryUsage) * 0.7)
        
        while totalMemoryUsage > targetUsage, 
              let oldestBuffer = activeBuffers.sorted(by: { $0.lastUsedTime < $1.lastUsedTime }).first {
            untrackBuffer(oldestBuffer)
        }
    }
    
    // MARK: - Buffer Processing
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        let managedBuffer = ManagedAudioBuffer(buffer: buffer)
        trackBuffer(managedBuffer)
        
        if config.optimizationPreset == .ultraLowLatency {
            // Process immediately for lowest latency
            processSingleBuffer(managedBuffer)
        } else {
            // Add to batch for better efficiency
            pendingBuffers.append((managedBuffer, Date()))
            batchProcessor?.addBuffer(managedBuffer)
        }
    }
    
    private func processBatch(_ buffers: [ManagedAudioBuffer]) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            autoreleasepool {
                // Process multiple buffers efficiently
                let features = self.fftProcessor.processBatch(buffers)
                
                // Update metrics
                self.processedBufferCount += buffers.count
                self.updatePerformanceMetrics()
                
                // Release buffers
                buffers.forEach { self.untrackBuffer($0) }
                
                // Notify completion
                DispatchQueue.main.async {
                    self.performanceMetrics.batchesProcessed += 1
                }
            }
        }
    }
    
    private func processSingleBuffer(_ buffer: ManagedAudioBuffer) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            autoreleasepool {
                if let features = self.fftProcessor.processBuffer(buffer.buffer) {
                    self.processedBufferCount += 1
                    self.updatePerformanceMetrics()
                }
                
                self.untrackBuffer(buffer)
            }
        }
    }
    
    // MARK: - Metrics and Monitoring
    
    private func updatePerformanceMetrics() {
        let now = Date()
        guard now.timeIntervalSince(lastMetricsUpdate) >= metricsUpdateInterval else { return }
        
        DispatchQueue.main.async {
            self.performanceMetrics.update(
                processedBuffers: self.processedBufferCount,
                memoryUsage: self.totalMemoryUsage,
                timeInterval: self.metricsUpdateInterval
            )
        }
        
        lastMetricsUpdate = now
        processedBufferCount = 0
    }
    
    private func updateMemoryMetrics() {
        DispatchQueue.main.async {
            self.performanceMetrics.currentMemoryUsage = self.totalMemoryUsage
            self.performanceMetrics.peakMemoryUsage = max(
                self.performanceMetrics.peakMemoryUsage,
                self.totalMemoryUsage
            )
        }
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

private class AudioBatchProcessor {
    private let maxBatchSize: Int
    private let processingInterval: TimeInterval
    private let processHandler: ([ManagedAudioBuffer]) -> Void
    private var buffers: [ManagedAudioBuffer] = []
    private var processingTimer: Timer?
    
    init(maxBatchSize: Int, processingInterval: TimeInterval, processHandler: @escaping ([ManagedAudioBuffer]) -> Void) {
        self.maxBatchSize = maxBatchSize
        self.processingInterval = processingInterval
        self.processHandler = processHandler
        setupTimer()
    }
    
    func addBuffer(_ buffer: ManagedAudioBuffer) {
        buffers.append(buffer)
        if buffers.count >= maxBatchSize {
            processBatch()
        }
    }
    
    func reset() {
        buffers.removeAll()
    }
    
    private func setupTimer() {
        processingTimer = Timer.scheduledTimer(
            withTimeInterval: processingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.processBatch()
        }
    }
    
    private func processBatch() {
        guard !buffers.isEmpty else { return }
        let batchBuffers = buffers
        buffers.removeAll()
        processHandler(batchBuffers)
    }
}

struct PerformanceMetrics {
    var processedBuffersPerSecond: Double = 0
    var currentMemoryUsage: Int = 0
    var peakMemoryUsage: Int = 0
    var batchesProcessed: Int = 0
    var averageProcessingTime: TimeInterval = 0
    
    mutating func update(processedBuffers: Int, memoryUsage: Int, timeInterval: TimeInterval) {
        processedBuffersPerSecond = Double(processedBuffers) / timeInterval
        currentMemoryUsage = memoryUsage
        peakMemoryUsage = max(peakMemoryUsage, memoryUsage)
    }
}
