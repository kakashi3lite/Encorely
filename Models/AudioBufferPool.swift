import Foundation
import AVFoundation

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
    
    func copyFrom(_ sourceBuffer: AVAudioPCMBuffer) {
        guard let sourceChannelData = sourceBuffer.floatChannelData,
              let targetChannelData = buffer.floatChannelData else {
            return
        }
        
        let framesToCopy = min(sourceBuffer.frameLength, buffer.frameCapacity)
        let bytesToCopy = Int(framesToCopy) * MemoryLayout<Float>.size
        
        for channel in 0..<Int(buffer.format.channelCount) {
            memcpy(targetChannelData[channel], sourceChannelData[channel], bytesToCopy)
        }
        
        buffer.frameLength = framesToCopy
        markUsed()
    }
    
    var memorySize: Int {
        Int(buffer.frameCapacity * buffer.format.streamDescription.pointee.mBytesPerFrame)
    }
    
    var idleTime: TimeInterval {
        return Date().timeIntervalSince(lastUseTime)
    }
    
    static func == (lhs: ManagedAudioBuffer, rhs: ManagedAudioBuffer) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
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
}

/// A pool for managing and reusing audio buffers with advanced memory management
class AudioBufferPool {
    // MARK: - Properties
    
    private var availableBuffers: [ManagedAudioBuffer] = []
    private var usedBuffers: Set<ManagedAudioBuffer> = []
    private let maxBuffers: Int
    private let bufferSize: UInt32
    private let queue = DispatchQueue(label: "audio.buffer.pool", attributes: .concurrent)
    private var totalMemoryUsage: Int = 0
    private let maxMemoryUsage: Int
    private let cleanupThreshold: TimeInterval = 30 // Cleanup buffers idle for 30+ seconds

    // Metrics tracking
    private var metrics = AudioBufferPoolMetrics()
    private let metricsQueue = DispatchQueue(label: "audio.buffer.pool.metrics")
    
    // MARK: - Memory Pressure Management
    
    enum MemoryPressureLevel: Int {
        case low = 0
        case moderate = 1
        case high = 2
        case critical = 3
        
        static func fromUsage(_ usage: Double) -> MemoryPressureLevel {
            switch usage {
            case 0..<0.6: return .low
            case 0.6..<0.75: return .moderate
            case 0.75..<0.9: return .high
            default: return .critical
            }
        }
    }
    
    // MARK: - Initialization

    init(maxBuffers: Int, bufferSize: UInt32) {
        self.maxBuffers = maxBuffers
        self.bufferSize = bufferSize
        self.maxMemoryUsage = 50 * 1024 * 1024 // 50MB limit
        
        // Pre-allocate some buffers but stay well under memory limits
        for _ in 0..<min(maxBuffers/4, 5) {
            if let buffer = createBuffer() {
                availableBuffers.append(buffer)
                totalMemoryUsage += buffer.memorySize
            }
        }
        
        startPeriodicCleanup()
    }
    
    // MARK: - Public Methods
    
    func getBuffer() -> ManagedAudioBuffer? {
        return queue.sync(flags: .barrier) {
            // First try to get an available buffer
            if let buffer = availableBuffers.popLast() {
                usedBuffers.insert(buffer)
                buffer.markUsed()
                updateMetrics(operation: "reuse")
                return buffer
            }
            
            // Check memory pressure before creating new buffer
            if shouldCreateNewBuffer() {
                if let buffer = createBuffer() {
                    usedBuffers.insert(buffer)
                    totalMemoryUsage += buffer.memorySize
                    buffer.markUsed()
                    updateMetrics(operation: "allocate")
                    return buffer
                }
            }
            
            // Try to reclaim an old buffer under memory pressure
            if let reclaimedBuffer = reclaimBuffer() {
                updateMetrics(operation: "reuse")
                return reclaimedBuffer
            }
            
            updateMetrics(operation: "miss")
            return nil
        }
    }
    
    func returnBuffer(_ buffer: ManagedAudioBuffer) {
        queue.async(flags: .barrier) {
            if self.usedBuffers.remove(buffer) != nil {
                // Only keep buffers that are reasonable size and not too old
                if buffer.idleTime < self.cleanupThreshold {
                    buffer.clear()
                    self.availableBuffers.append(buffer)
                } else {
                    self.totalMemoryUsage -= buffer.memorySize
                }
                self.updateMetrics(operation: "release")
            }
        }
    }
    
    func releaseAllBuffers() {
        queue.async(flags: .barrier) {
            self.totalMemoryUsage = 0
            self.availableBuffers.removeAll()
            self.usedBuffers.removeAll()
            self.updateMetrics(operation: "reset")
        }
    }
    
    func getPoolMetrics() -> AudioBufferPoolMetrics {
        return metricsQueue.sync { metrics }
    }
    
    // MARK: - Private Methods
    
    private func createBuffer() -> ManagedAudioBuffer? {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize) else {
            return nil
        }
        return ManagedAudioBuffer(buffer: buffer)
    }
    
    private func shouldCreateNewBuffer() -> Bool {
        let currentPressure = Double(totalMemoryUsage) / Double(maxMemoryUsage)
        let totalBuffers = usedBuffers.count + availableBuffers.count
        
        return totalMemoryUsage < maxMemoryUsage * 3/4 && 
               totalBuffers < maxBuffers &&
               currentPressure < 0.8
    }
    
    private func reclaimBuffer() -> ManagedAudioBuffer? {
        // First try buffers idle for half the cleanup threshold
        if let oldBuffer = findOldestBuffer() {
            oldBuffer.clear()
            oldBuffer.markUsed()
            return oldBuffer
        }
        
        // Under high pressure, more aggressive reclamation
        if Double(totalMemoryUsage) / Double(maxMemoryUsage) > 0.9 {
            if let anyBuffer = usedBuffers.first {
                anyBuffer.clear()
                anyBuffer.markUsed()
                return anyBuffer
            }
        }
        
        return nil
    }
    
    private func findOldestBuffer() -> ManagedAudioBuffer? {
        return usedBuffers
            .filter { $0.idleTime > cleanupThreshold/2 }
            .max(by: { $0.idleTime < $1.idleTime })
    }
    
    private func startPeriodicCleanup() {
        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func performCleanup() {
        queue.async(flags: .barrier) {
            let now = Date()
            var freedMemory = 0
            
            // Remove old available buffers with adaptive threshold
            let memoryPressure = Double(self.totalMemoryUsage) / Double(self.maxMemoryUsage)
            let adaptiveThreshold = self.cleanupThreshold * (memoryPressure > 0.7 ? 0.5 : 1.0)
            
            self.availableBuffers.removeAll { buffer in
                let shouldRemove = buffer.idleTime > adaptiveThreshold
                if shouldRemove {
                    freedMemory += buffer.memorySize
                }
                return shouldRemove
            }
            
            // Clean up used buffers based on pressure
            self.usedBuffers = self.usedBuffers.filter { buffer in
                let keepBuffer = memoryPressure <= 0.8 || buffer.idleTime < adaptiveThreshold
                if !keepBuffer {
                    freedMemory += buffer.memorySize
                }
                return keepBuffer
            }
            
            self.totalMemoryUsage -= freedMemory
            
            // Update metrics
            if freedMemory > 0 {
                self.updateMetrics(operation: "cleanup", freedMemory: freedMemory)
            }
            
            // Schedule next cleanup based on pressure
            let nextInterval = memoryPressure > 0.7 ? 5.0 : 10.0
            DispatchQueue.main.asyncAfter(deadline: .now() + nextInterval) {
                self.performCleanup()
            }
        }
    }
    
    func reducePoolSize() {
        queue.async(flags: .barrier) {
            let targetMemory = self.maxMemoryUsage / 2
            
            // First remove available buffers
            while self.totalMemoryUsage > targetMemory && !self.availableBuffers.isEmpty {
                if let buffer = self.availableBuffers.popLast() {
                    self.totalMemoryUsage -= buffer.memorySize
                }
            }
            
            // Then remove old used buffers if needed
            if self.totalMemoryUsage > targetMemory {
                let oldBuffers = self.usedBuffers.filter { $0.idleTime > self.cleanupThreshold/2 }
                    .sorted { $0.idleTime > $1.idleTime }
                
                for buffer in oldBuffers {
                    if self.totalMemoryUsage <= targetMemory {
                        break
                    }
                    if self.usedBuffers.remove(buffer) != nil {
                        self.totalMemoryUsage -= buffer.memorySize
                    }
                }
            }
            
            self.updateMetrics(operation: "reduce")
        }
    }
    
    private func updateMetrics(operation: String, freedMemory: Int = 0) {
        metricsQueue.async {
            switch operation {
            case "allocate":
                self.metrics.totalAllocations += 1
                self.metrics.peakMemoryUsage = max(self.metrics.peakMemoryUsage, self.totalMemoryUsage)
            case "release":
                self.metrics.totalReleases += 1
            case "reuse":
                self.metrics.reuseCount += 1
            case "miss":
                self.metrics.missedRequests += 1
            case "cleanup":
                self.metrics.totalReleases += 1
            case "reset":
                self.metrics.totalAllocations = 0
                self.metrics.totalReleases = 0
                self.metrics.reuseCount = 0
            default: break
            }
            
            self.metrics.currentMemoryUsage = self.totalMemoryUsage
            self.metrics.memoryPressureLevel = MemoryPressureLevel.fromUsage(
                Double(self.totalMemoryUsage) / Double(self.maxMemoryUsage)
            )
        }
    }
}
