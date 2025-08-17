import CoreML
import Foundation
import Vision

/// Configuration for Core ML models and AI processing
public enum MLConfig {
    // MARK: - Analysis Parameters

    enum Analysis {
        static let confidenceThreshold: Float = 0.65
        static let moodUpdateInterval: TimeInterval = 5.0
        static let moodHistorySize = 10
        static let moodStabilityFactor: Float = 0.7
    }

    // MARK: - Feature Extraction Settings

    enum FeatureExtraction {
        static let fftSize = 2048
        static let hopSize = 512
        static let sampleRate: Double = 44100
        static let melBands = 128
        static let windowSize = 2048
        static let minFrequency: Float = 20
        static let maxFrequency: Float = 20000
    }

    // MARK: - Performance Settings

    enum Performance {
        #if os(macOS)
            static let maxProcessingLatency: TimeInterval = 0.15 // 150ms for macOS
            static let maxMemoryUsage = 100 * 1024 * 1024 // 100MB for macOS
            static let targetFPS: Double = 30.0 // Higher FPS for macOS
            static let maxConcurrentOperations = 8 // More concurrent operations on macOS
        #else
            static let maxProcessingLatency: TimeInterval = 0.10 // 100ms for iOS
            static let maxMemoryUsage = 50 * 1024 * 1024 // 50MB for iOS
            static let targetFPS: Double = 20.0 // Lower FPS for iOS
            static let maxConcurrentOperations = 4 // Fewer concurrent operations on iOS
        #endif

        static let maxBufferSize = 1024 * 1024 // 1MB
        static let maxCacheSize = 100 * 1024 * 1024 // 100MB
        static let maxHistorySize = 1000
    }

    // MARK: - Device Adaptation

    enum DeviceAdaptation {
        static let adaptToDeviceCapabilities = true
        static let lowPowerModeEnabled = true
        static let adaptToThermalState = true
        #if os(macOS)
            static let backgroundProcessingEnabled = true // Enable background processing on macOS
            static let useMetalAcceleration = true // Enable Metal acceleration on macOS
        #else
            static let backgroundProcessingEnabled = false // Disable on iOS by default
            static let useMetalAcceleration = false // Disable on iOS by default
        #endif
    }

    // MARK: - Core ML Model Configuration

    enum Model {
        static var modelURL: URL {
            Bundle.main.url(forResource: "MoodClassifier", withExtension: "mlmodelc")!
        }

        static let modelVersion = "2.0.0"
        static let minimumConfidence: Float = 0.6

        #if os(macOS)
            static let defaultDevice = "mps" // Use Metal Performance Shaders on macOS
            static let computeUnits = "all" // Use all available compute units
        #else
            static let defaultDevice = "cpu" // Use CPU on iOS for better battery life
            static let computeUnits = "cpuAndNeuralEngine" // Use CPU and Neural Engine if available
        #endif
    }

    // MARK: - Audio Analysis Configuration

    enum AudioAnalysis {
        static let spectralAnalysisEnabled = true
        static let tempoDetectionEnabled = true
        static let moodDetectionEnabled = true
        static let onsetDetectionEnabled = true

        static let defaultOptions: AnalysisOptions = [
            .spectralAnalysis,
            .tempoAnalysis,
            .loudnessAnalysis,
            .rhythmAnalysis,
            .moodAnalysis,
            .cachingEnabled,
        ]

        static let highPrecisionOptions: AnalysisOptions = defaultOptions.union([
            .harmonicAnalysis,
            .highPrecision,
        ])
    }

    // MARK: - Error Handling

    enum ErrorHandling {
        static let maxRetries = 3
        static let retryDelay: TimeInterval = 1.0
        static let timeoutInterval: TimeInterval = 30.0

        static let recoveryEnabled = true
        static let errorLoggingEnabled = true
        static let errorReportingEnabled = true
    }
}

// MARK: - Analysis Options

public struct AnalysisOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let spectralAnalysis = AnalysisOptions(rawValue: 1 << 0)
    static let tempoAnalysis = AnalysisOptions(rawValue: 1 << 1)
    static let pitchAnalysis = AnalysisOptions(rawValue: 1 << 2)
    static let loudnessAnalysis = AnalysisOptions(rawValue: 1 << 3)
    static let rhythmAnalysis = AnalysisOptions(rawValue: 1 << 4)
    static let moodAnalysis = AnalysisOptions(rawValue: 1 << 5)
    static let harmonicAnalysis = AnalysisOptions(rawValue: 1 << 6)
    static let cachingEnabled = AnalysisOptions(rawValue: 1 << 7)
    static let highPrecision = AnalysisOptions(rawValue: 1 << 8)
    static let lowLatency = AnalysisOptions(rawValue: 1 << 9)
}

// MARK: - Model Loading Helper

extension MLConfig {
    static func loadModel<T: MLModel>(_ asset: MLConfig.ModelAsset) throws -> T {
        do {
            // Try loading optimized model
            if let url = asset.url {
                return try T(contentsOf: url, configuration: defaultConfiguration())
            }
            // Fall back to compiled model
            if let fallbackUrl = asset.fallbackURL {
                return try T(contentsOf: fallbackUrl, configuration: defaultConfiguration())
            }
            throw AppError.modelLoadFailed
        } catch {
            throw AppError.modelLoadFailed
        }
    }
}
