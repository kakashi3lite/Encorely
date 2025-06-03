import Foundation
import AVFoundation
import os.log

/// Represents different levels of memory pressure
enum MemoryPressureLevel: Int, Comparable {
    case low = 0
    case moderate = 1
    case high = 2
    case critical = 3
    
    static func < (lhs: MemoryPressureLevel, rhs: MemoryPressureLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Notification names for buffer pool events
extension Notification.Name {
    static let audioBufferPoolMetricsUpdated = Notification.Name("AudioBufferPoolMetricsUpdated")
}

/// Performance metrics for the buffer pool
struct AudioBufferPoolMetrics {
    var totalAllocations: Int = 0
    var totalReleases: Int = 0
    var peakMemoryUsage: Int = 0
    var averageBufferLifetime: TimeInterval = 0
    var missedRequests: Int = 0
    var reuseCount: Int = 0
    var currentMemoryUsage: Int = 0
    var memoryPressureLevel: MemoryPressureLevel = .low
    
    mutating func recordAllocation() {
        totalAllocations += 1
    }
    
    mutating func recordRelease() {
        totalReleases += 1
    }
    
    mutating func recordReuse() {
        reuseCount += 1
    }
    
    mutating func recordMissedRequest() {
        missedRequests += 1
    }
    
    mutating func updateMemoryUsage(_ usage: Int) {
        currentMemoryUsage = usage
        peakMemoryUsage = max(peakMemoryUsage, usage)
    }
}

/// A managed audio buffer that can be pooled and reused
class ManagedAudioBuffer: Hashable {
    let buffer: AVAudioPCMBuffer
    private let id = UUID()
    private var lastUseTime = Date()
    private var useCount = 0
    
    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
        markUsed()
    }
    
    func markUsed() {
        lastUseTime = Date()
        useCount += 1
    }
    
    func clear() {
        guard let channelData = buffer.floatChannelData else { return }
        for channel in 0..<Int(buffer.format.channelCount) {
            memset(channelData[channel], 0, Int(buffer.frameCapacity) * MemoryLayout<Float>.size)
        }
        buffer.frameLength = 0
    }
    
    var memorySize: Int {
        Int(buffer.frameCapacity * buffer.format.streamDescription.pointee.mBytesPerFrame)
    }
    
    var idleTime: TimeInterval {
        Date().timeIntervalSince(lastUseTime)
    }
    
    static func == (lhs: ManagedAudioBuffer, rhs: ManagedAudioBuffer) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// A pool for managing and reusing audio buffers with advanced memory management
class AudioBufferPool {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.aimixtapes", category: "AudioBufferPool")
    private var availableBuffers: [ManagedAudioBuffer] = []
    private var usedBuffers: Set<ManagedAudioBuffer> = []
    private let queue = DispatchQueue(label: "audio.buffer.pool", attributes: .concurrent)
    private var totalMemoryUsage: Int = 0
    private let maxMemoryUsage: Int
    private let cleanupThreshold: TimeInterval = 30 // seconds
    
    // Enhanced metrics tracking
    private var metrics = AudioBufferPoolMetrics() {
        didSet {
            NotificationCenter.default.post(name: .audioBufferPoolMetricsUpdated, object: metrics)
        }
    }
    
    // Adaptive buffer management
    private var pressureLevel: MemoryPressureLevel = .low {
        didSet {
            if pressureLevel > oldValue {
                handleIncreasedMemoryPressure()
            }
        }
    }
    private var lastCleanupTime = Date()
    private let cleanupInterval: TimeInterval = 5.0
    private var bufferAgeThresholds: [MemoryPressureLevel: TimeInterval] = [
        .low: 30.0,
        .moderate: 20.0,
        .high: 10.0,
        .critical: 5.0
    ]
    
    // Buffer configuration
    private let format: AVAudioFormat
    private let frameCapacity: AVAudioFrameCount
    
    // MARK: - Initialization
    
    init(format: AVAudioFormat, frameCapacity: AVAudioFrameCount, maxMemoryMB: Int = 50) {
        self.format = format
        self.frameCapacity = frameCapacity
        self.maxMemoryUsage = maxMemoryMB * 1024 * 1024
        setupPeriodicCleanup()
        setupMemoryPressureMonitoring()
        preAllocateBuffers(count: 5)
    }
    
    // MARK: - Public Methods
    
    func getBuffer() -> ManagedAudioBuffer? {
        return queue.sync { [weak self] in
            guard let self = self else { return nil }
            
            // First try to reuse an available buffer
            if let buffer = self.availableBuffers.popLast() {
                self.usedBuffers.insert(buffer)
                buffer.markUsed()
                self.metrics.recordReuse()
                return buffer
            }
            
            // Create new buffer if memory allows
            if self.shouldCreateNewBuffer() {
                if let buffer = self.createBuffer() {
                    self.usedBuffers.insert(buffer)
                    self.metrics.recordAllocation()
                    self.updateMemoryMetrics()
                    return buffer
                }
            }
            
            self.metrics.recordMissedRequest()
            self.logger.warning("Failed to provide buffer - memory pressure: \(self.pressureLevel)")
            return nil
        }
    }
    
    func returnBuffer(_ buffer: ManagedAudioBuffer) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if self.usedBuffers.remove(buffer) != nil {
                buffer.clear() // Clear buffer data
                
                // Only keep buffer if memory pressure isn't high
                if self.pressureLevel < .high {
                    self.availableBuffers.append(buffer)
                } else {
                    self.totalMemoryUsage -= buffer.memorySize
                }
                
                self.metrics.recordRelease()
                self.updateMemoryMetrics()
            }
        }
    }
    
    func releaseAllBuffers() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.availableBuffers.removeAll()
            self.usedBuffers.removeAll()
            self.totalMemoryUsage = 0
            self.updateMemoryMetrics()
            self.logger.info("Released all buffers")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMemoryPressureMonitoring() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #endif
        
        // Monitor memory pressure periodically
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updatePressureLevel()
        }
    }
    
    private func setupPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            self?.performPeriodicCleanup()
        }
    }
    
    @objc private func handleMemoryWarning() {
        pressureLevel = .critical
        performEmergencyCleanup()
    }
    
    private func handleIncreasedMemoryPressure() {
        switch pressureLevel {
        case .critical:
            performEmergencyCleanup()
        case .high:
            performAggressiveCleanup()
        case .moderate:
            performGradualCleanup()
        default:
            break
        }
    }
    
    private func performEmergencyCleanup() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Clear all available buffers
            self.availableBuffers.removeAll()
            
            // Keep only recently used buffers
            let now = Date()
            let oldBuffers = self.usedBuffers.filter {
                now.timeIntervalSince($0.lastUsedTime) > 2.0
            }
            
            for buffer in oldBuffers {
                self.usedBuffers.remove(buffer)
                self.totalMemoryUsage -= buffer.memorySize
            }
            
            self.updateMemoryMetrics()
            self.logger.info("Emergency cleanup completed")
        }
    }
    
    private func performAggressiveCleanup() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Clear old available buffers
            self.availableBuffers.removeAll {
                $0.idleTime > 5.0
            }
            
            // Remove old used buffers
            let oldBuffers = self.usedBuffers.filter {
                $0.idleTime > 10.0
            }
            
            for buffer in oldBuffers {
                self.usedBuffers.remove(buffer)
                self.totalMemoryUsage -= buffer.memorySize
            }
            
            self.updateMemoryMetrics()
        }
    }
    
    private func performGradualCleanup() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Remove oldest available buffers
            while !self.availableBuffers.isEmpty && 
                  self.totalMemoryUsage > self.maxMemoryUsage * 3/4 {
                _ = self.availableBuffers.removeFirst()
            }
            
            self.updateMemoryMetrics()
        }
    }
    
    private func updatePressureLevel() {
        let usage = Double(totalMemoryUsage) / Double(maxMemoryUsage)
        let newLevel: MemoryPressureLevel
        
        switch usage {
        case 0.0..<0.6:
            newLevel = .low
        case 0.6..<0.75:
            newLevel = .moderate
        case 0.75..<0.9:
            newLevel = .high
        default:
            newLevel = .critical
        }
        
        if newLevel != pressureLevel {
            pressureLevel = newLevel
            logger.info("Memory pressure level changed to: \(String(describing: newLevel))")
        }
    }
    
    private func updateMemoryMetrics() {
        metrics.updateMemoryUsage(totalMemoryUsage)
        metrics.memoryPressureLevel = pressureLevel
    }
    
    private func createBuffer() -> ManagedAudioBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            logger.error("Failed to create audio buffer")
            return nil
        }
        
        let managed = ManagedAudioBuffer(buffer: buffer)
        totalMemoryUsage += managed.memorySize
        
        return managed
    }
    
    private func shouldCreateNewBuffer() -> Bool {
        guard pressureLevel < .high else { return false }
        
        let proposedUsage = totalMemoryUsage + estimateBufferSize()
        return proposedUsage <= maxMemoryUsage
    }
    
    private func estimateBufferSize() -> Int {
        return Int(frameCapacity * format.streamDescription.pointee.mBytesPerFrame)
    }
    
    private func preAllocateBuffers(count: Int) {
        for _ in 0..<count {
            if let buffer = createBuffer() {
                availableBuffers.append(buffer)
            }
        }
        updateMemoryMetrics()
    }
}
