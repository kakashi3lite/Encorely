import Foundation
import SwiftUI
import Combine
import os.log
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// A service that monitors and tracks app performance metrics
final class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    private let logger = Logger(subsystem: "com.ai-mixtapes", category: "Performance")
    private var metrics: [String: TimeInterval] = [:]
    private var periodicMetrics: [String: [Double]] = [:]
    private var memoryWarningSubscriber: AnyCancellable?
    private var cpuUsageTimer: Timer?
    private var diskUsageTimer: Timer?
    private var configurationObserver: AnyCancellable?
    
    // Connection to configuration system
    private var configuration: AudioProcessingConfiguration {
        return AudioProcessingConfiguration.shared
    }
    
    private init() {
        setupMemoryWarningObserver()
        setupPeriodicMonitoring()
        setupConfigurationObserver()
    }
    
    /// Starts tracking a performance metric
    func startTracking(_ identifier: String) {
        metrics[identifier] = Date().timeIntervalSinceReferenceDate
    }
    
    /// Ends tracking a performance metric and logs the duration
    func endTracking(_ identifier: String) {
        guard let startTime = metrics[identifier] else {
            logger.error("No start time found for metric: \(identifier)")
            return
        }
        
        let duration = Date().timeIntervalSinceReferenceDate - startTime
        logger.info("\(identifier) took \(duration) seconds")
        
        // Store in periodic metrics for trend analysis
        var measurements = periodicMetrics[identifier, default: []]
        measurements.append(duration)
        if measurements.count > 100 { // Keep last 100 measurements
            measurements.removeFirst()
        }
        periodicMetrics[identifier] = measurements
        
        metrics.removeValue(forKey: identifier)
    }
    
    /// Reports current memory usage
    func reportMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            logger.info("Memory used: \(usedMB) MB")
            
            #if os(macOS)
            // Check virtual memory pressure on macOS
            let hostPort = mach_host_self()
            var hostVMInfo = vm_statistics64()
            var vmInfoSize = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
            
            let vmResult = hostVMInfo.withUnsafeMutableBytes { bytes in
                host_statistics64(hostPort,
                                HOST_VM_INFO64,
                                bytes.baseAddress!.assumingMemoryBound(to: host_info_t.self),
                                &vmInfoSize)
            }
            
            if vmResult == KERN_SUCCESS {
                let totalPages = hostVMInfo.wire_count + hostVMInfo.active_count + hostVMInfo.inactive_count + hostVMInfo.free_count
                let pressureLevel = Double(hostVMInfo.wire_count + hostVMInfo.active_count) / Double(totalPages)
                logger.info("Memory pressure level: \(pressureLevel)")
                
                if pressureLevel > 0.8 {
                    handleHighMemoryPressure()
                }
            }
            #endif
        }
    }
    
    /// Reports CPU usage for the app
    private func reportCPUUsage() {
        var thread_list: thread_act_array_t?
        var thread_count: mach_msg_type_number_t = 0
        
        let task_threads_result = task_threads(mach_task_self_, &thread_list, &thread_count)
        
        if task_threads_result == KERN_SUCCESS, let threadList = thread_list {
            var totalCPU: Double = 0
            
            for i in 0..<Int(thread_count) {
                var thread_info_count = mach_msg_type_number_t(THREAD_INFO_MAX)
                var thinfo = thread_basic_info()
                
                let kr = withUnsafeMutablePointer(to: &thinfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadList[i],
                                  thread_flavor_t(THREAD_BASIC_INFO),
                                  $0,
                                  &thread_info_count)
                    }
                }
                
                if kr == KERN_SUCCESS {
                    totalCPU += Double(thinfo.cpu_usage) / Double(TH_USAGE_SCALE)
                }
            }
            
            logger.info("Total CPU usage: \(totalCPU * 100)%")
            
            #if os(macOS)
            if totalCPU > 0.7 { // 70% threshold
                handleHighCPUUsage()
            }
            #endif
            
            vm_deallocate(mach_task_self_,
                         vm_address_t(UInt(bitPattern: thread_list)),
                         vm_size_t(Int(thread_count) * MemoryLayout<thread_t>.stride))
        }
    }
    
    private func setupPeriodicMonitoring() {
        // Monitor CPU usage every 5 seconds
        cpuUsageTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.reportCPUUsage()
        }
        
        // Monitor disk usage every minute
        diskUsageTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.reportDiskUsage()
        }
    }
    
    private func reportDiskUsage() {
        do {
            let fileManager = FileManager.default
            if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let resourceValues = try appSupportURL.resourceValues(forKeys: [.volumeAvailableCapacityKey, .volumeTotalCapacityKey])
                if let availableCapacity = resourceValues.volumeAvailableCapacity,
                   let totalCapacity = resourceValues.volumeTotalCapacity {
                    let usedPercentage = Double(totalCapacity - availableCapacity) / Double(totalCapacity) * 100
                    logger.info("Disk usage: \(usedPercentage)%")
                    
                    #if os(macOS)
                    if usedPercentage > 90 {
                        handleHighDiskUsage()
                    }
                    #endif
                }
            }
        } catch {
            logger.error("Failed to get disk usage: \(error.localizedDescription)")
        }
    }
    
    #if os(macOS)
    private func handleHighMemoryPressure() {
        logger.warning("High memory pressure detected")
        // Notify observers about high memory pressure
        NotificationCenter.default.post(name: .performanceHighMemoryPressure, object: nil)
    }
    
    private func handleHighCPUUsage() {
        logger.warning("High CPU usage detected")
        // Notify observers about high CPU usage
        NotificationCenter.default.post(name: .performanceHighCPUUsage, object: nil)
    }
    
    private func handleHighDiskUsage() {
        logger.warning("High disk usage detected")
        // Notify observers about high disk usage
        NotificationCenter.default.post(name: .performanceHighDiskUsage, object: nil)
    }
    #endif
    
    private func setupMemoryWarningObserver() {
        #if os(iOS)
        memoryWarningSubscriber = NotificationCenter.default
            .publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
        #endif
    }
    
    private func handleMemoryWarning() {
        logger.warning("Memory warning received")
        reportMemoryUsage()
        NotificationCenter.default.post(name: .performanceMemoryWarning, object: nil)
    }
    
    deinit {
        cpuUsageTimer?.invalidate()
        diskUsageTimer?.invalidate()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let performanceMemoryWarning = Notification.Name("PerformanceMemoryWarning")
    static let performanceHighMemoryPressure = Notification.Name("PerformanceHighMemoryPressure")
    static let performanceHighCPUUsage = Notification.Name("PerformanceHighCPUUsage")
    static let performanceHighDiskUsage = Notification.Name("PerformanceHighDiskUsage")
    static let audioProcessingValidationCompleted = Notification.Name("AudioProcessingValidationCompleted")
}

// MARK: - View Modifier
struct PerformanceTracking: ViewModifier {
    let identifier: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                PerformanceMonitor.shared.startTracking(identifier)
            }
            .onDisappear {
                PerformanceMonitor.shared.endTracking(identifier)
            }
    }
}

extension View {
    func trackPerformance(identifier: String) -> some View {
        modifier(PerformanceTracking(identifier: identifier))
    }
}

// MARK: - Audio Processing Performance Validation

extension PerformanceMonitor {
    /// Run a comprehensive validation of the audio processing system
    func validateAudioProcessingSystem() async -> ValidationResult {
        logger.info("Starting audio processing system validation...")
        
        let validator = PerformanceValidator()
        let results = await validator.validatePerformanceConstraints()
        
        // Log results summary
        logger.info("Audio processing validation completed. Overall: \(results.overallPassed ? "PASSED" : "FAILED")")
        logger.info("Latency: \(String(format: "%.1f", results.latencyResult.averageLatencyMs))ms - \(results.latencyResult.passed ? "PASSED" : "FAILED")")
        logger.info("Memory: \(String(format: "%.1f", results.memoryResult.peakMemoryMB))MB - \(results.memoryResult.passed ? "PASSED" : "FAILED")")
        logger.info("Accuracy: \(String(format: "%.1f", results.accuracyResult.accuracy * 100))% - \(results.accuracyResult.passed ? "PASSED" : "FAILED")")
        
        // Post notification with results
        NotificationCenter.default.post(
            name: .audioProcessingValidationCompleted,
            object: nil,
            userInfo: ["results": results]
        )
        
        return results
    }
    
    /// Setup configuration observer for AudioProcessingConfiguration
    private func setupConfigurationObserver() {
        // Observe configuration changes
        configurationObserver = AudioProcessingConfiguration.shared.configurationChanged
            .sink { [weak self] _ in
                self?.applyConfigurationSettings()
            }
        
        // Apply initial settings
        applyConfigurationSettings()
    }
    
    private func applyConfigurationSettings() {
        let config = AudioProcessingConfiguration.shared
        
        // Update monitoring based on configuration
        let enableMonitoring = config.enablePerformanceMonitoring
        
        // Adjust CPU usage timer
        if enableMonitoring {
            if cpuUsageTimer == nil {
                cpuUsageTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                    self?.reportCPUUsage()
                }
            }
        } else {
            cpuUsageTimer?.invalidate()
            cpuUsageTimer = nil
        }
        
        // Log configuration
        logger.info("Applied performance settings: maxLatency=\(config.maxProcessingLatency)s, maxMemory=\(config.maxMemoryUsage/1024/1024)MB, FPS=\(config.targetFPS)")
    }
}
