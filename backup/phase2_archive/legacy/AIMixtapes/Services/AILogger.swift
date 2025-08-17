import Combine
import CoreML
import Foundation
import os.log

final class AILogger {
    static let shared = AILogger()

    // MARK: - Publishers

    @Published private(set) var inferenceMetrics: [String: TimeInterval] = [:]
    @Published private(set) var modelAccuracy: [String: Float] = [:]
    @Published private(set) var userFeedback: [String: Int] = [:]
    @Published private(set) var systemMetrics: SystemMetrics = .init()

    // MARK: - Performance Tracking

    private var performanceMetrics: [String: [TimeInterval]] = [:]
    private var userInteractions: [String: Date] = [:]
    private var errorCounts: [String: Int] = [:]
    private let queue = DispatchQueue(label: "com.aimixtapes.ailogger", qos: .utility)

    // MARK: - OS Logging

    private let logger = Logger(subsystem: "com.aimixtapes.ai", category: "AILogger")

    // MARK: - Resource Monitoring

    private let resourceMonitor = ResourceMonitor()
    private var monitoringTimer: Timer?

    private init() {
        setupPeriodicReporting()
        startResourceMonitoring()
    }

    // MARK: - Public Interface

    func logInference(model: String, duration: TimeInterval, success: Bool) {
        queue.async {
            self.performanceMetrics[model, default: []].append(duration)
            self.inferenceMetrics[model] = self.calculateAverageInferenceTime(for: model)

            if !success {
                self.logError(model: model, error: .inferenceError)
                self.logger.error("Inference failed for model: \(model)")
            }

            self.logger.info("Inference completed - model: \(model), duration: \(duration), success: \(success)")
        }
    }

    func logAccuracy(model: String, predictedValue: Any, actualValue: Any) {
        queue.async {
            let accuracy = self.calculateAccuracy(predicted: predictedValue, actual: actualValue)
            self.modelAccuracy[model] = accuracy

            if accuracy < MLConfig.Thresholds.minimumEmotionConfidence {
                self.logError(model: model, error: .insufficientData)
                self.logger.warning("Low accuracy detected for model: \(model), accuracy: \(accuracy)")
            }
        }
    }

    func logUserFeedback(feature: String, isPositive: Bool) {
        queue.async {
            let currentCount = self.userFeedback[feature] ?? 0
            self.userFeedback[feature] = currentCount + (isPositive ? 1 : -1)
        }
    }

    func logUserInteraction(type: String) {
        queue.async {
            self.userInteractions[type] = Date()
        }
    }

    // MARK: - Error Handling

    func logError(model: String, error: AppError) {
        queue.async {
            self.errorCounts[model, default: 0] += 1

            let errorContext = [
                "model": model,
                "error": String(describing: error),
                "count": self.errorCounts[model] ?? 1,
                "timestamp": Date().timeIntervalSince1970,
            ] as [String: Any]

            self.logger.error("AI Error occurred: \(error.localizedDescription, privacy: .public)")
            NotificationCenter.default.post(name: .aiServiceError, object: error, userInfo: errorContext)

            if self.errorCounts[model, default: 0] >= MLConfig.Thresholds.maxErrorsBeforeAlert {
                self.handleCriticalError(model: model, error: error)
            }
        }
    }

    // MARK: - Analytics

    func getModelPerformanceReport() -> [String: Any] {
        queue.sync {
            [
                "inferenceMetrics": inferenceMetrics,
                "modelAccuracy": modelAccuracy,
                "userFeedback": userFeedback,
                "totalInteractions": userInteractions.count,
                "errorCounts": errorCounts,
                "systemMetrics": systemMetrics.dictionaryRepresentation(),
            ]
        }
    }

    func resetMetrics() {
        queue.async {
            self.performanceMetrics.removeAll()
            self.inferenceMetrics.removeAll()
            self.modelAccuracy.removeAll()
            self.userFeedback.removeAll()
            self.userInteractions.removeAll()
            self.errorCounts.removeAll()
            self.systemMetrics = SystemMetrics()
        }
    }

    // MARK: - Private Helpers

    private func calculateAverageInferenceTime(for model: String) -> TimeInterval {
        guard let metrics = performanceMetrics[model], !metrics.isEmpty else {
            return 0
        }
        return metrics.reduce(0, +) / Double(metrics.count)
    }

    private func calculateAccuracy(predicted _: Any, actual _: Any) -> Float {
        // Implementation depends on type of prediction
        // For now, return a mock value
        0.85
    }

    private func setupPeriodicReporting() {
        Timer
            .scheduledTimer(withTimeInterval: MLConfig.Monitoring.performanceLoggingInterval,
                            repeats: true)
            { [weak self] _ in
                self?.queue.async {
                    self?.exportMetrics()
                }
            }
    }

    private func exportMetrics() {
        queue.async {
            let report = self.getModelPerformanceReport()
            self.logger.info("Exporting metrics: \(report)")

            // In production, send to analytics service
            #if DEBUG
                print("AI Performance Report:")
                dump(report)
            #endif
        }
    }

    private func startResourceMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateSystemMetrics()
        }
    }

    private func updateSystemMetrics() {
        queue.async {
            self.systemMetrics = self.resourceMonitor.getCurrentMetrics()

            if self.systemMetrics.memoryUsage > MLConfig.Thresholds.maxMemoryUsage {
                self.logger.warning("High memory usage detected: \(self.systemMetrics.memoryUsage) MB")
            }

            if self.systemMetrics.cpuUsage > MLConfig.Thresholds.maxCPUUsage {
                self.logger.warning("High CPU usage detected: \(self.systemMetrics.cpuUsage)%")
            }
        }
    }

    private func handleCriticalError(model: String, error: AppError) {
        logger.critical("Critical error threshold reached for model: \(model)")

        // Notify development team
        #if DEBUG
            print("⚠️ CRITICAL: Model \(model) has encountered multiple errors")
            print("Error details: \(error)")
        #endif

        // In production, send alert to monitoring service
    }

    private func debugPrint(model: String, duration: TimeInterval, success: Bool) {
        print("""
        AI Inference Log:
        - Model: \(model)
        - Duration: \(String(format: "%.3f", duration))s
        - Success: \(success)
        - Avg Time: \(String(format: "%.3f", inferenceMetrics[model] ?? 0))s
        """)
    }
}

// MARK: - Supporting Types

struct SystemMetrics {
    var cpuUsage: Double = 0
    var memoryUsage: UInt64 = 0
    var diskUsage: Double = 0
    var thermalState: ProcessInfo.ThermalState = .nominal

    func dictionaryRepresentation() -> [String: Any] {
        [
            "cpu": cpuUsage,
            "memory": memoryUsage,
            "disk": diskUsage,
            "thermal": thermalState.rawValue,
        ]
    }
}

class ResourceMonitor {
    func getCurrentMetrics() -> SystemMetrics {
        var metrics = SystemMetrics()

        metrics.cpuUsage = getCPUUsage()
        metrics.memoryUsage = getMemoryUsage()
        metrics.diskUsage = getDiskUsage()
        metrics.thermalState = ProcessInfo.processInfo.thermalState

        return metrics
    }

    private func getCPUUsage() -> Double {
        // Implementation for CPU usage monitoring
        var totalUsageOfCPU = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        let threadsResult = task_threads(mach_task_self_, &threadsList, &threadsCount)

        if threadsResult == KERN_SUCCESS, let threadsList {
            for index in 0 ..< threadsCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(index)],
                                    thread_flavor_t(THREAD_BASIC_INFO),
                                    $0,
                                    &threadInfoCount)
                    }
                }

                if infoResult == KERN_SUCCESS {
                    let threadBasicInfo = threadInfo
                    if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                        totalUsageOfCPU = (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
                    }
                }
            }

            vm_deallocate(mach_task_self_,
                          vm_address_t(UInt(bitPattern: threadsList)),
                          vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        }

        return totalUsageOfCPU
    }

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }

        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }

    private func getDiskUsage() -> Double {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return 0
        }

        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: documentDirectory.path)
            if let freeSize = attributes[.systemFreeSize] as? NSNumber {
                return 100.0 - (Double(freeSize.int64Value) / Double(attributes[.systemSize] as? Int64 ?? 1) * 100.0)
            }
        } catch {
            print("Error getting disk usage: \(error)")
        }
        return 0
    }
}
