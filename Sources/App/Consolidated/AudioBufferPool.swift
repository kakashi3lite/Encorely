import AVFoundation
import Foundation
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif
import os.log

/// Enhanced memory pressure level tracking
enum MemoryPressureLevel: Int, Comparable {
    case low = 0
    case moderate = 1
    case high = 2
    case critical = 3

    var thresholdPercentage: Double {
        switch self {
        case .low: 0.60
        case .moderate: 0.75
        case .high: 0.85
        case .critical: 0.95
        }
    }

    var maxBufferAge: TimeInterval {
        switch self {
        case .low: 30.0
        case .moderate: 20.0
        case .high: 10.0
        case .critical: 5.0
        }
    }

    static func < (lhs: MemoryPressureLevel, rhs: MemoryPressureLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(memoryUsage: Double) -> MemoryPressureLevel {
        switch memoryUsage {
        case 0.0 ..< 0.6: .low
        case 0.6 ..< 0.75: .moderate
        case 0.75 ..< 0.85: .high
        default: .critical
        }
    }
}

/// Performance metrics with enhanced memory tracking
struct AudioBufferPoolMetrics {
    var totalAllocations: Int = 0
    var totalReleases: Int = 0
    var peakMemoryUsage: Int = 0
    var currentMemoryUsage: Int = 0
    var reuseCount: Int = 0
    var missedRequests: Int = 0
    var averageBufferLifetime: TimeInterval = 0
    var bufferEfficiency: Double = 0.0
    var memoryPressureLevel: MemoryPressureLevel = .low
    var recentMemoryTrend: [Int] = []

    mutating func recordAllocation() {
        totalAllocations += 1
        updateEfficiency()
    }

    mutating func recordRelease() {
        totalReleases += 1
        updateEfficiency()
    }

    mutating func recordReuse() {
        reuseCount += 1
        updateEfficiency()
    }

    mutating func recordMissedRequest() {
        missedRequests += 1
    }

    mutating func updateMemoryUsage(_ usage: Int) {
        currentMemoryUsage = usage
        peakMemoryUsage = max(peakMemoryUsage, usage)

        // Keep track of recent memory usage trend
        if recentMemoryTrend.count > 20 {
            recentMemoryTrend.removeFirst()
        }
        recentMemoryTrend.append(usage)
    }

    private mutating func updateEfficiency() {
        if totalAllocations > 0 {
            bufferEfficiency = Double(reuseCount) / Double(totalAllocations) * 100
        }
    }

    var memoryTrend: Double {
        guard recentMemoryTrend.count >= 2 else { return 0 }
        let changes = zip(recentMemoryTrend.dropLast(), recentMemoryTrend.dropFirst())
            .map { $1 - $0 }
        return Double(changes.reduce(0, +)) / Double(changes.count)
    }
}

/// Notification names for buffer pool events
extension Notification.Name {
    static let audioBufferPoolMetricsUpdated = Notification.Name("AudioBufferPoolMetricsUpdated")
    static let audioBufferPoolPressureChanged = Notification.Name("AudioBufferPoolPressureChanged")
    static let audioBufferPoolEmergencyCleanup = Notification.Name("AudioBufferPoolEmergencyCleanup")
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
        for channel in 0 ..< Int(buffer.format.channelCount) {
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
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// A pool for managing and reusing audio buffers with advanced memory management
final class AudioBufferPool {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.aimixtapes", category: "AudioBufferPool")
    private let queue = DispatchQueue(label: "audio.buffer.pool", attributes: .concurrent)
    private let memoryMonitor = MemoryMonitor.shared
    private let lifecycle = AudioBufferLifecycle()

    private var availableBuffers: [ManagedAudioBuffer] = []
    private var usedBuffers: Set<ManagedAudioBuffer> = []
    private var metrics = AudioBufferPoolMetrics()

    private let format: AVAudioFormat
    private let frameCapacity: AVAudioFrameCount
    private let maxMemoryUsage: Int
    private let cleanupInterval: TimeInterval = 2.0 // More frequent cleanup

    private var lastCleanupTime = Date()
    private var totalMemoryUsage: Int = 0
    private var pressureLevel: MemoryPressureLevel = .low {
        didSet {
            if pressureLevel > oldValue {
                handleIncreasedMemoryPressure()
            }
        }
    }

    // Enhanced memory thresholds
    private let pressureThresholds: [MemoryPressureLevel: Double] = [
        .low: 0.60,
        .moderate: 0.75,
        .high: 0.85,
        .critical: 0.95,
    ]

    // MARK: - Initialization

    init(format: AVAudioFormat, frameCapacity: AVAudioFrameCount, maxMemoryMB: Int = 50) {
        self.format = format
        self.frameCapacity = frameCapacity
        maxMemoryUsage = maxMemoryMB * 1024 * 1024

        setupMemoryPressureMonitoring()
        setupPeriodicCleanup()
        configureInitialBuffers()
    }

    // MARK: - Setup Functions

    private func setupMemoryPressureMonitoring() {
        // Monitor memory pressure and respond accordingly
        #if canImport(UIKit)
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleIncreasedMemoryPressure()
            }
        #endif
    }

    private func setupPeriodicCleanup() {
        // Set up periodic buffer cleanup every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.performGradualCleanup()
        }
    }

    // MARK: - Memory Management

    private func handleIncreasedMemoryPressure() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }

            switch pressureLevel {
            case .critical:
                performEmergencyCleanup()
                NotificationCenter.default.post(name: .audioBufferPoolEmergencyCleanup, object: nil)

            case .high:
                performAggressiveCleanup()

            case .moderate:
                performGradualCleanup()

            default:
                break
            }

            updateMemoryMetrics()
        }
    }

    private func performEmergencyCleanup() {
        // Clear all available buffers
        availableBuffers.removeAll()

        // Keep only essential buffers (very recently used or frequent)
        let essentialBuffers = usedBuffers.filter {
            $0.idleTime < 1.0 || $0.usageFrequency > 2.0
        }

        // Remove all non-essential buffers
        let removedBuffers = usedBuffers.subtracting(essentialBuffers)
        for buffer in removedBuffers {
            totalMemoryUsage -= buffer.memorySize
        }

        usedBuffers = essentialBuffers

        // Force memory pressure recalculation
        updateMemoryMetrics()
    }

    private func performAggressiveCleanup() {
        let now = Date()
        let targetUsage = Int(Double(maxMemoryUsage) * 0.6) // Target 60% usage

        // Sort buffers by value (combination of frequency and recency)
        let sortedBuffers = usedBuffers.sorted { b1, b2 in
            let value1 = b1.usageFrequency / (b1.idleTime + 1)
            let value2 = b2.usageFrequency / (b2.idleTime + 1)
            return value1 < value2
        }

        var freedMemory = 0
        for buffer in sortedBuffers {
            if totalMemoryUsage - freedMemory <= targetUsage {
                break
            }

            if buffer.idleTime > 5.0, buffer.usageFrequency < 1.0 {
                usedBuffers.remove(buffer)
                freedMemory += buffer.memorySize
            }
        }

        totalMemoryUsage -= freedMemory
        updatePressureLevel()
    }

    private func updatePressureLevel() {
        let usage = Double(totalMemoryUsage) / Double(maxMemoryUsage)
        let trend = metrics.memoryTrend

        // Adjust pressure based on both current usage and trend
        let newLevel: MemoryPressureLevel = if usage > pressureThresholds[.critical]! || trend > Double(
            maxMemoryUsage
        ) /
            20
        {
            .critical
        } else if usage > pressureThresholds[.high]! || trend > Double(maxMemoryUsage) / 40 {
            .high
        } else if usage > pressureThresholds[.moderate]! {
            .moderate
        } else {
            .low
        }

        if newLevel != pressureLevel {
            pressureLevel = newLevel
            logger.info("Memory pressure level changed to: \(String(describing: newLevel))")
            NotificationCenter.default.post(name: .audioBufferPoolPressureChanged, object: pressureLevel)
        }
    }

    private func performGradualCleanup() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }

            let now = Date()
            let targetUsage = Int(Double(maxMemoryUsage) * 0.75) // Target 75% usage

            // Remove old available buffers first
            let oldAvailableBuffers = availableBuffers.filter {
                $0.idleTime > self.pressureLevel.maxBufferAge
            }
            availableBuffers.removeAll {
                oldAvailableBuffers.contains($0)
            }

            // Then gradually remove old used buffers if needed
            if totalMemoryUsage > targetUsage {
                let oldUsedBuffers = usedBuffers.filter {
                    now.timeIntervalSince($0.lastUsedTime) > self.pressureLevel.maxBufferAge &&
                        $0.usageFrequency < 0.5
                }

                for buffer in oldUsedBuffers {
                    usedBuffers.remove(buffer)
                    totalMemoryUsage -= buffer.memorySize

                    if totalMemoryUsage <= targetUsage {
                        break
                    }
                }
            }

            updateMemoryMetrics()
            logger.info("Gradual cleanup complete")
        }
    }

    private func updateMemoryMetrics() {
        metrics.updateMemoryUsage(totalMemoryUsage)
        metrics.memoryPressureLevel = pressureLevel

        NotificationCenter.default.post(name: .audioBufferPoolMetricsUpdated, object: metrics)
    }

    private func configureInitialBuffers() {
        // Pre-allocate a few buffers to reduce initial latency
        for _ in 0 ..< 5 {
            if let buffer = createBuffer() {
                availableBuffers.append(buffer)
            }
        }

        updateMemoryMetrics()
        logger.info("Pre-allocated \(availableBuffers.count) buffers")
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
}

// MARK: - CustomStringConvertible

extension MemoryPressureLevel: CustomStringConvertible {
    var description: String {
        switch self {
        case .low: "Low"
        case .moderate: "Moderate"
        case .high: "High"
        case .critical: "Critical"
        }
    }
}
