import Foundation
import SwiftUI
import Combine
import os.log

/// A service that monitors and tracks app performance metrics
final class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    private let logger = Logger(subsystem: "com.ai-mixtapes", category: "Performance")
    private var metrics: [String: TimeInterval] = [:]
    private var memoryWarningSubscriber: AnyCancellable?
    
    private init() {
        setupMemoryWarningObserver()
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
        }
    }
    
    private func setupMemoryWarningObserver() {
        memoryWarningSubscriber = NotificationCenter.default
            .publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
    }
    
    private func handleMemoryWarning() {
        logger.warning("Memory warning received")
        reportMemoryUsage()
        NotificationCenter.default.post(name: .performanceMemoryWarning, object: nil)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let performanceMemoryWarning = Notification.Name("PerformanceMemoryWarning")
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
