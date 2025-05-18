import Foundation
import CoreML
import Combine

/// Logs and analyzes AI-related metrics and events
final class AILogger {
    static let shared = AILogger()
    
    // MARK: - Publishers
    @Published private(set) var inferenceMetrics: [String: TimeInterval] = [:]
    @Published private(set) var modelAccuracy: [String: Float] = [:]
    @Published private(set) var userFeedback: [String: Int] = [:]
    
    // MARK: - Performance Tracking
    private var performanceMetrics: [String: [TimeInterval]] = [:]
    private var userInteractions: [String: Date] = [:]
    private let queue = DispatchQueue(label: "com.aimixtapes.ailogger", qos: .utility)
    
    private init() {
        setupPeriodicReporting()
    }
    
    // MARK: - Public Interface
    
    func logInference(model: String, duration: TimeInterval, success: Bool) {
        queue.async {
            self.performanceMetrics[model, default: []].append(duration)
            self.inferenceMetrics[model] = self.calculateAverageInferenceTime(for: model)
            
            if !success {
                self.logError(model: model, error: .inferenceError)
            }
            
            #if DEBUG
            self.debugPrint(model: model, duration: duration, success: success)
            #endif
        }
    }
    
    func logAccuracy(model: String, predictedValue: Any, actualValue: Any) {
        queue.async {
            // Calculate accuracy based on prediction type
            let accuracy = self.calculateAccuracy(predicted: predictedValue, actual: actualValue)
            self.modelAccuracy[model] = accuracy
            
            if accuracy < MLConfig.Thresholds.minimumEmotionConfidence {
                self.logError(model: model, error: .insufficientData)
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
        NotificationCenter.default.post(
            name: .aiServiceError,
            object: error
        )
        
        #if DEBUG
        print("AI Error: model=\(model) error=\(error.localizedDescription)")
        #endif
    }
    
    // MARK: - Analytics
    
    func getModelPerformanceReport() -> [String: Any] {
        queue.sync {
            [
                "inferenceMetrics": inferenceMetrics,
                "modelAccuracy": modelAccuracy,
                "userFeedback": userFeedback,
                "totalInteractions": userInteractions.count
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
        }
    }
    
    // MARK: - Private Helpers
    
    private func calculateAverageInferenceTime(for model: String) -> TimeInterval {
        guard let metrics = performanceMetrics[model], !metrics.isEmpty else {
            return 0
        }
        return metrics.reduce(0, +) / Double(metrics.count)
    }
    
    private func calculateAccuracy(predicted: Any, actual: Any) -> Float {
        // Implementation depends on type of prediction
        // For now, return a mock value
        return 0.85
    }
    
    private func setupPeriodicReporting() {
        Timer.scheduledTimer(withTimeInterval: MLConfig.Monitoring.performanceLoggingInterval, repeats: true) { [weak self] _ in
            self?.queue.async {
                self?.exportMetrics()
            }
        }
    }
    
    private func exportMetrics() {
        let report = getModelPerformanceReport()
        #if DEBUG
        print("AI Performance Report: \(report)")
        #endif
        // In production, send to analytics service or save locally
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