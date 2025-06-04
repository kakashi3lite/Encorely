//
//  AudioProcessor.swift
//  Mixtapes
//
//  Enhanced audio processor with proper memory management
//  Supporting ISSUE-005: Memory Management in Audio Buffers
//

import Foundation
import AVFoundation
import Accelerate
import os.log

/// Dedicated memory manager for audio processing
final class MemoryManager {
    static let shared = MemoryManager()
    private let logger = Logger(subsystem: "com.aimixtapes", category: "MemoryManager")
    
    // Memory thresholds
    private let criticalThreshold = 0.95
    private let highThreshold = 0.85
    private let moderateThreshold = 0.75
    
    // Memory monitoring
    private var memoryPressureTimer: Timer?
    private let monitoringInterval: TimeInterval = 2.0
    
    private init() {
        setupMemoryMonitoring()
    }
    
    private func setupMemoryMonitoring() {
        memoryPressureTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.checkMemoryPressure()
        }
        RunLoop.main.add(memoryPressureTimer!, forMode: .common)
    }
    
    func checkMemoryPressure() {
        let usage = currentMemoryUsage()
        switch usage {
        case _ where usage >= criticalThreshold:
            NotificationCenter.default.post(name: .memoryPressureCritical, object: nil)
        case _ where usage >= highThreshold:
            NotificationCenter.default.post(name: .memoryPressureHigh, object: nil)
        case _ where usage >= moderateThreshold:
            NotificationCenter.default.post(name: .memoryPressureModerate, object: nil)
        default:
            break
        }
    }
    
    private func currentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { 
            logger.error("Failed to get memory usage")
            return 0.0 
        }
        
        return Double(info.resident_size)
    }
}

// Memory pressure notification extensions
extension Notification.Name {
    static let memoryPressureCritical = Notification.Name("MemoryPressureCritical")
    static let memoryPressureHigh = Notification.Name("MemoryPressureHigh")
    static let memoryPressureModerate = Notification.Name("MemoryPressureModerate")
}

/// Enhanced AudioProcessor with proper memory management and batch processing
class AudioProcessor: ObservableObject {
    
    // MARK: - Properties
    private let audioAnalysisService: AudioAnalysisService
    private var isProcessing = false
    private var processingCompletion: ((AudioFeatures) -> Void)?
    
    // Memory management
    private let processQueue = DispatchQueue(label: "audio.process.queue", qos: .userInteractive)
    private var activeProcessingTasks: Set<UUID> = []
    private let maxConcurrentTasks = 3
    private var memoryWarningObserver: NSObjectProtocol?
    private var totalMemoryUsage: Int = 0
    private let maxMemoryUsage = 50 * 1024 * 1024 // 50MB limit
    private var avgMemoryUsagePerBuffer: Double = 0
    private let bufferLock = NSLock()
    private var activeBuffers = Set<ManagedAudioBuffer>()
    
    // Batch processing
    private let batchProcessor: AudioBatchProcessor
    private let batchSize = 10
    private var pendingBuffers: [(buffer: ManagedAudioBuffer, timestamp: Date)] = []
    
    // Performance metrics
    @Published private(set) var memoryUsage: Int = 0
    @Published private(set) var bufferProcessingLoad: Double = 0
    private var processingTimes: [TimeInterval] = []
    private let maxProcessingTimes = 50
    
    // Performance monitoring
    private let performanceMonitor = PerformanceMonitor()
    
    // MARK: - Initialization
    init(audioAnalysisService: AudioAnalysisService) {
        self.audioAnalysisService = audioAnalysisService
        self.batchProcessor = AudioBatchProcessor(maxBatchSize: batchSize)
        setupMemoryManagement()
        setupPerformanceMonitoring()
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        cleanupBuffers()
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryManagement() {
        // Memory pressure notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCriticalMemoryPressure),
            name: .memoryPressureCritical,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHighMemoryPressure),
            name: .memoryPressureHigh,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleModerateMemoryPressure),
            name: .memoryPressureModerate,
            object: nil
        )
    }
    
    private func setupPerformanceMonitoring() {
        performanceMonitor.startMonitoring()
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
        
        // Release all buffers from pool
        DispatchQueue.main.async { [weak self] in
            self?.memoryUsage = 0
            self?.updateMemoryMetrics()
        }
    }
    
    private func checkMemoryPressure() {
        let pressure = Double(totalMemoryUsage) / Double(maxMemoryUsage)
        
        switch pressure {
        case 0.9...: // Critical pressure
            handleCriticalMemoryPressure()
        case 0.8...: // High pressure
            handleHighMemoryPressure()
        case 0.7...: // Moderate pressure
            handleModerateMemoryPressure()
        default:
            break
        }
    }
    
    @objc private func handleCriticalMemoryPressure() {
        performEmergencyCleanup()
    }
    
    @objc private func handleHighMemoryPressure() {
        performAggressiveCleanup()
    }
    
    @objc private func handleModerateMemoryPressure() {
        performGradualCleanup()
    }
    
    private func performEmergencyCleanup() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        // Clear all buffers
        activeBuffers.forEach { untrackBuffer($0) }
        activeBuffers.removeAll()
        
        // Clear pending batches
        pendingBuffers.removeAll()
        batchProcessor.reset()
        
        // Cancel non-essential tasks
        cancelNonEssentialTasks()
        
        totalMemoryUsage = 0
        performanceMonitor.recordCleanup()
    }
    
    private func performAggressiveCleanup() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        // Remove old buffers
        let now = Date()
        let oldBuffers = activeBuffers.filter {
            now.timeIntervalSince($0.lastUsedTime) > 5.0
        }
        
        oldBuffers.forEach { untrackBuffer($0) }
        
        // Clear old pending buffers
        pendingBuffers.removeAll { 
            now.timeIntervalSince($0.timestamp) > 2.0
        }
        
        performanceMonitor.recordCleanup()
    }
    
    private func performGradualCleanup() {
        let targetUsage = maxMemoryUsage * 3/4
        
        while totalMemoryUsage > targetUsage,
              let oldestBuffer = activeBuffers.sorted(by: { $0.lastUsedTime < $1.lastUsedTime }).first {
            untrackBuffer(oldestBuffer)
        }
        
        performanceMonitor.recordCleanup()
    }
    
    private func untrackBuffer(_ buffer: ManagedAudioBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        if activeBuffers.remove(buffer) != nil {
            totalMemoryUsage -= buffer.memorySize
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.memoryUsage = self?.totalMemoryUsage ?? 0
            self?.updateMemoryMetrics()
        }
    }
    
    private func cancelNonEssentialTasks() {
        processQueue.async { [weak self] in
            self?.activeProcessingTasks.forEach { taskId in
                // Cancel tasks that aren't actively processing
                if self?.isProcessing == false {
                    self?.activeProcessingTasks.remove(taskId)
                }
            }
        }
    }
    
    private func reduceActiveTaskCount() {
        let maxTasks = maxConcurrentTasks / 2
        while activeProcessingTasks.count > maxTasks {
            _ = activeProcessingTasks.popFirst()
        }
    }
    
    private func updateMemoryMetrics() {
        let usage = Double(totalMemoryUsage) / Double(maxMemoryUsage) * 100
        DispatchQueue.main.async { [weak self] in
            self?.bufferProcessingLoad = usage
        }
    }
    
    // MARK: - Public Methods
    
    /// Start real-time analysis with proper resource management
    func startRealTimeAnalysis(completion: @escaping (AudioFeatures) -> Void) throws {
        guard !isProcessing else {
            throw AppError.audioProcessingFailed(NSError(domain: "AudioProcessor", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Processing already in progress"]))
        }
        
        isProcessing = true
        processingCompletion = completion
        
        try audioAnalysisService.startRealTimeAnalysis { [weak self] features in
            self?.handleProcessedFeatures(features)
        }
    }
    
    /// Stop real-time analysis and cleanup
    func stopRealTimeAnalysis() {
        isProcessing = false
        processingCompletion = nil
        audioAnalysisService.stopRealTimeAnalysis()
        
        // Cancel ongoing tasks and cleanup
        activeProcessingTasks.removeAll()
        cleanupBuffers()
    }
    
    /// Process audio file with memory-safe batching
    func processAudioFile(_ url: URL, completion: @escaping (Result<AudioFeatures, Error>) -> Void) {
        let taskId = UUID()
        
        if activeProcessingTasks.count >= maxConcurrentTasks {
            handleHighMemoryPressure() // Try to free up resources
            if activeProcessingTasks.count >= maxConcurrentTasks {
                completion(.failure(AppError.audioProcessingFailed(NSError(domain: "AudioProcessor",
                    code: 2002,
                    userInfo: [NSLocalizedDescriptionKey: "Too many concurrent processing tasks"]))))
                return
            }
        }
        
        activeProcessingTasks.insert(taskId)
        
        Task { [weak self] in
            do {
                let features = try await self?.audioAnalysisService.analyzeAudioFile(url)
                
                DispatchQueue.main.async {
                    self?.activeProcessingTasks.remove(taskId)
                    if let features = features {
                        completion(.success(features))
                    } else {
                        completion(.failure(AppError.audioProcessingFailed(nil)))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.activeProcessingTasks.remove(taskId)
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Buffer Processing
    
    private func processBuffer(_ buffer: ManagedAudioBuffer) {
        if pendingBuffers.count >= batchSize {
            processPendingBatch()
        }
        
        pendingBuffers.append((buffer: buffer, timestamp: Date()))
        performanceMonitor.recordBufferProcessed()
    }
    
    private func processPendingBatch() {
        guard !pendingBuffers.isEmpty else { return }
        
        let batch = pendingBuffers
        pendingBuffers.removeAll()
        
        batchProcessor.processBatch(batch.map { $0.buffer }) { [weak self] features in
            self?.handleBatchProcessed(features)
        }
    }
    
    private func handleBatchProcessed(_ features: [AudioFeatures]) {
        DispatchQueue.main.async { [weak self] in
            self?.performanceMonitor.recordBatchProcessed(count: features.count)
            // Handle features...
        }
    }
    
    private func handleProcessedFeatures(_ features: AudioFeatures) {
        guard isProcessing, let completion = processingCompletion else { return }
        
        DispatchQueue.main.async {
            completion(features)
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
}
