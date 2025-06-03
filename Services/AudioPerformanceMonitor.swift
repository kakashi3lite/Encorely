import Foundation
import os.log
import AVFoundation

/// Comprehensive performance monitoring for audio processing
final class AudioPerformanceMonitor {
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.aimixtapes", category: "PerformanceMonitor")
    
    // Performance thresholds
    struct Thresholds {
        static let maxProcessingTime: TimeInterval = 0.1 // 100ms
        static let targetProcessingTime: TimeInterval = 0.05 // 50ms
        static let maxMemoryUsage: Int = 100 * 1024 * 1024 // 100MB
        static let targetMemoryUsage: Int = 50 * 1024 * 1024 // 50MB
        static let maxCPUUsage: Double = 0.8 // 80%
        static let targetCPUUsage: Double = 0.5 // 50%
    }
    
    // Processing metrics
    private(set) var processedBufferCount: Int = 0
    private(set) var processedBatchCount: Int = 0
    private(set) var totalProcessingTime: TimeInterval = 0
    private(set) var averageProcessingTime: TimeInterval = 0
    private(set) var peakProcessingTime: TimeInterval = 0
    
    // Memory metrics
    private(set) var peakMemoryUsage: Int = 0
    private(set) var currentMemoryUsage: Int = 0
    private(set) var averageMemoryUsage: Int = 0
    private(set) var memoryUsageSamples: [Int] = []
    
    // CPU metrics
    private(set) var currentCPUUsage: Double = 0
    private(set) var peakCPUUsage: Double = 0
    private(set) var averageCPUUsage: Double = 0
    private(set) var cpuUsageSamples: [Double] = []
    
    // Performance status
    private(set) var performanceStatus: PerformanceStatus = .normal {
        didSet {
            if performanceStatus != oldValue {
                handlePerformanceStatusChange(from: oldValue, to: performanceStatus)
            }
        }
    }
    
    // Monitoring
    private var monitoringTimer: Timer?
    private var startTime: Date?
    private let monitoringInterval: TimeInterval = 1.0
    
    // History
    private var processingTimes: [TimeInterval] = []
    private let maxHistoryEntries = 100
    
    // MARK: - Initialization
    
    init() {
        setupMonitoring()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        startTime = Date()
        setupMonitoringTimer()
        logger.info("Performance monitoring started")
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        startTime = nil
        logger.info("Performance monitoring stopped")
    }
    
    func recordBufferProcessed(processingTime: TimeInterval) {
        processedBufferCount += 1
        totalProcessingTime += processingTime
        peakProcessingTime = max(peakProcessingTime, processingTime)
        
        processingTimes.append(processingTime)
        if processingTimes.count > maxHistoryEntries {
            processingTimes.removeFirst()
        }
        
        updateAverageProcessingTime()
        checkProcessingTimeThresholds()
    }
    
    func recordBatchProcessed(count: Int, processingTime: TimeInterval) {
        processedBatchCount += 1
        processedBufferCount += count
        recordBufferProcessed(processingTime: processingTime)
    }
    
    func recordMemoryUsage(_ usage: Int) {
        currentMemoryUsage = usage
        peakMemoryUsage = max(peakMemoryUsage, usage)
        
        memoryUsageSamples.append(usage)
        if memoryUsageSamples.count > maxHistoryEntries {
            memoryUsageSamples.removeFirst()
        }
        
        updateAverageMemoryUsage()
        checkMemoryThresholds()
    }
    
    func recordCPUUsage(_ usage: Double) {
        currentCPUUsage = usage
        peakCPUUsage = max(peakCPUUsage, usage)
        
        cpuUsageSamples.append(usage)
        if cpuUsageSamples.count > maxHistoryEntries {
            cpuUsageSamples.removeFirst()
        }
        
        updateAverageCPUUsage()
        checkCPUThresholds()
    }
    
    func generateReport() -> PerformanceReport {
        return PerformanceReport(
            duration: startTime.map { Date().timeIntervalSince($0) } ?? 0,
            bufferMetrics: BufferMetrics(
                processedCount: processedBufferCount,
                batchCount: processedBatchCount,
                averageProcessingTime: averageProcessingTime,
                peakProcessingTime: peakProcessingTime
            ),
            memoryMetrics: MemoryMetrics(
                current: currentMemoryUsage,
                peak: peakMemoryUsage,
                average: averageMemoryUsage
            ),
            cpuMetrics: CPUMetrics(
                current: currentCPUUsage,
                peak: peakCPUUsage,
                average: averageCPUUsage
            ),
            status: performanceStatus
        )
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoringTimer() {
        monitoringTimer = Timer.scheduledTimer(
            withTimeInterval: monitoringInterval,
            repeats: true
        ) { [weak self] _ in
            self?.updateMetrics()
        }
        RunLoop.main.add(monitoringTimer!, forMode: .common)
    }
    
    private func updateMetrics() {
        updateMemoryMetrics()
        updateCPUMetrics()
        updatePerformanceStatus()
        notifyMetricsUpdated()
    }
    
    private func updateMemoryMetrics() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            recordMemoryUsage(Int(info.resident_size))
        }
    }
    
    private func updateCPUMetrics() {
        // Implementation for CPU usage monitoring
        // This is platform specific and may require different approaches for iOS/macOS
    }
    
    private func updateAverageProcessingTime() {
        guard !processingTimes.isEmpty else { return }
        averageProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
    }
    
    private func updateAverageMemoryUsage() {
        guard !memoryUsageSamples.isEmpty else { return }
        averageMemoryUsage = memoryUsageSamples.reduce(0, +) / memoryUsageSamples.count
    }
    
    private func updateAverageCPUUsage() {
        guard !cpuUsageSamples.isEmpty else { return }
        averageCPUUsage = cpuUsageSamples.reduce(0, +) / Double(cpuUsageSamples.count)
    }
    
    private func checkProcessingTimeThresholds() {
        if averageProcessingTime > Thresholds.maxProcessingTime {
            logger.warning("Processing time exceeds maximum threshold")
            performanceStatus = .degraded
        }
    }
    
    private func checkMemoryThresholds() {
        if currentMemoryUsage > Thresholds.maxMemoryUsage {
            logger.warning("Memory usage exceeds maximum threshold")
            performanceStatus = .critical
        }
    }
    
    private func checkCPUThresholds() {
        if currentCPUUsage > Thresholds.maxCPUUsage {
            logger.warning("CPU usage exceeds maximum threshold")
            performanceStatus = .degraded
        }
    }
    
    private func updatePerformanceStatus() {
        let newStatus: PerformanceStatus
        
        switch (currentMemoryUsage, currentCPUUsage, averageProcessingTime) {
        case _ where currentMemoryUsage > Thresholds.maxMemoryUsage:
            newStatus = .critical
        case _ where currentCPUUsage > Thresholds.maxCPUUsage:
            newStatus = .degraded
        case _ where averageProcessingTime > Thresholds.maxProcessingTime:
            newStatus = .degraded
        case _ where currentMemoryUsage <= Thresholds.targetMemoryUsage &&
                   currentCPUUsage <= Thresholds.targetCPUUsage &&
                   averageProcessingTime <= Thresholds.targetProcessingTime:
            newStatus = .normal
        default:
            newStatus = .warning
        }
        
        performanceStatus = newStatus
    }
    
    private func handlePerformanceStatusChange(from oldStatus: PerformanceStatus, to newStatus: PerformanceStatus) {
        logger.info("Performance status changed from \(oldStatus) to \(newStatus)")
        NotificationCenter.default.post(
            name: .performanceStatusChanged,
            object: nil,
            userInfo: ["status": newStatus]
        )
    }
    
    private func notifyMetricsUpdated() {
        NotificationCenter.default.post(
            name: .performanceMetricsUpdated,
            object: nil,
            userInfo: ["metrics": generateReport()]
        )
    }
}

// MARK: - Supporting Types

enum PerformanceStatus: String {
    case normal
    case warning
    case degraded
    case critical
}

struct PerformanceReport {
    let duration: TimeInterval
    let bufferMetrics: BufferMetrics
    let memoryMetrics: MemoryMetrics
    let cpuMetrics: CPUMetrics
    let status: PerformanceStatus
}

struct BufferMetrics {
    let processedCount: Int
    let batchCount: Int
    let averageProcessingTime: TimeInterval
    let peakProcessingTime: TimeInterval
}

struct MemoryMetrics {
    let current: Int
    let peak: Int
    let average: Int
}

struct CPUMetrics {
    let current: Double
    let peak: Double
    let average: Double
}

extension Notification.Name {
    static let performanceStatusChanged = Notification.Name("PerformanceStatusChanged")
    static let performanceMetricsUpdated = Notification.Name("PerformanceMetricsUpdated")
}
