import CoreML
import Vision
import Foundation

/// Configuration for Core ML models and AI processing
enum MLConfig {
    // MARK: - Model Versioning
    static let emotionModelVersion = "v1.0.0"
    static let audioFeatureModelVersion = "v1.0.0"
    static let personalityModelVersion = "v1.0.0"
    
    // MARK: - Performance Settings
    struct Performance {
        #if os(macOS)
        static let maxProcessingLatency: TimeInterval = 0.04  // 40ms target for macOS
        static let maxMemoryUsage: Int = 50 * 1024 * 1024    // 50MB for macOS
        static let targetFPS: Double = 30.0                   // Higher FPS target for macOS
        #else
        static let maxProcessingLatency: TimeInterval = 0.04  // 40ms target for iOS
        static let maxMemoryUsage: Int = 5 * 1024 * 1024     // 5MB for iOS
        static let targetFPS: Double = 20.0                   // Standard FPS for iOS
        #endif
        
        static let computeUnits: MLComputeUnits = .all
        static let preferredMetalDevice = MTLCreateSystemDefaultDevice()
        static let allowLowPrecisionAccumulationOnGPU = true
        static let preferredMemoryFootprint: MLModelConfiguration.PreferredMemoryFootprint = .smallest
        static let minimumPersonalityConfidence: Float = 0.6
        static let minimumRecommendationScore: Float = 0.5
        static let maxCPUUsage: Double = 80.0  // 80%
        static let maxDiskUsage: Double = 90.0  // 90%
        static let maxErrorsBeforeAlert = 5
        static let maxRetryAttempts = 3
        static let retryDelaySeconds: TimeInterval = 1.0
        static let maximumAudioDuration: TimeInterval = 600.0  // 10 minutes
        static let minimumSampleRate: Double = 44100.0
    }
    
    // MARK: - Model Configuration
    static func defaultConfiguration() -> MLModelConfiguration {
        let config = MLModelConfiguration()
        config.computeUnits = computeUnits
        config.preferredMetalDevice = MTLCreateSystemDefaultDevice()
        config.allowLowPrecisionAccumulationOnGPU = allowLowPrecisionAccumulationOnGPU
        config.preferredMemoryFootprint = preferredMemoryFootprint
        return config
    }
    
    // MARK: - Vision Configuration
    static func visionConfiguration() -> VNImageRequestHandler.Options {
        [.preferBackgroundProcessing: true,
         .reportProgress: true,
         .usesCPUOnly: false]
    }
    
    // MARK: - Error Recovery
    struct ErrorRecovery {
        static let maxRetryAttempts = 3
        static let retryDelay: TimeInterval = 1.0
        static let useGracefulDegradation = true
        static let progressiveBackoff = true
        
        static func shouldRetry(_ error: Error, attempts: Int) -> Bool {
            guard attempts < maxRetryAttempts else { return false }
            return (error as NSError).domain == MLModelErrorDomain
        }
        
        static func calculateRetryDelay(attempt: Int) -> TimeInterval {
            guard progressiveBackoff else { return retryDelay }
            return retryDelay * TimeInterval(attempt * attempt)
        }
    }
    
    // MARK: - Model Paths
    enum ModelAsset: String {
        case emotionClassifier = "EmotionClassifier"
        case audioFeatures = "AudioFeatures"
        case personalityPredictor = "PersonalityPredictor"
        case emotionClassifierOptimized = "EmotionClassifier_optimized"
        
        var url: URL? {
            // Try to load optimized model first
            if self == .emotionClassifier,
               let optimizedUrl = Bundle.main.url(forResource: ModelAsset.emotionClassifierOptimized.rawValue, withExtension: "mlmodelc") {
                return optimizedUrl
            }
            return Bundle.main.url(forResource: rawValue, withExtension: "mlmodelc")
        }
        
        var fallbackURL: URL? {
            // Fallback to compiled model in app bundle
            Bundle.main.url(forResource: "\(rawValue)_fallback", withExtension: "mlmodelc")
        }
    }
    
    // MARK: - Monitoring
    struct Monitoring {
        static let logMLMetrics = true
        static let collectPerformanceMetrics = true
        static let performanceLoggingInterval: TimeInterval = 60.0
        static let maxBufferCacheSize: Int = 50 * 1024 * 1024  // 50MB
        static let maxCachedBuffers: Int = 10
        static let bufferCleanupInterval: TimeInterval = 300.0  // 5 minutes
        static let metricsUploadInterval: TimeInterval = 3600.0  // 1 hour
        static let detailedLoggingEnabled = true
        
        static func logInference(model: String, duration: TimeInterval, success: Bool) {
            guard logMLMetrics else { return }
            // Implementation for logging ML metrics
            #if DEBUG
            print("ML Inference: model=\(model) duration=\(duration) success=\(success)")
            #endif
        }
    }
    
    // MARK: - ML Model configurations
    struct Models {
        static let minimumConfidenceThreshold: Float = 0.7
        static let batchSize = 10
        static let maxSequenceLength = 512
        static let computeUnits: MLComputeUnits = .all
    }
    
    // MARK: - Update intervals
    struct UpdateIntervals {
        static let modelUpdate: TimeInterval = 86400 // 24 hours
        static let analysisInterval: TimeInterval = 0.1
        static let moodUpdateInterval: TimeInterval = 300 // 5 minutes
    }
    
    // MARK: - Feature extraction parameters
    struct FeatureExtraction {
        static let fftSize = 2048
        static let hopSize = 512
        static let sampleRate: Double = 44100
        static let melBands = 128
        static let windowSize = 2048
    }
    
    // MARK: - Memory management
    struct Memory {
        static let maxBufferSize = 1024 * 1024 // 1MB
        static let maxCacheSize = 100 * 1024 * 1024 // 100MB
        static let maxHistorySize = 1000
    }
    
    // MARK: - API Configuration
    struct API {
        static let baseURL = "https://api.aimixtapes.com"
        static let version = "v1"
        static let timeout: TimeInterval = 30
        static let maxRetries = 3
        static let retryDelay: TimeInterval = 5
    }
    
    // MARK: - Resource Management
    struct ResourceManagement {
        static let enableAutomaticMemoryReduction = true
        static let memoryWarningThreshold: Float = 0.8  // 80% of available memory
        static let modelUnloadThreshold: TimeInterval = 300.0  // 5 minutes of inactivity
        
        static func shouldUnloadModel(lastUsed: Date) -> Bool {
            return Date().timeIntervalSince(lastUsed) > modelUnloadThreshold
        }
    }
    
    // MARK: - Feature Flags
    struct FeatureFlags {
        static let enableRealtimeAnalysis = true
        static let enableOfflineProcessing = true
        static let enableBatchProcessing = true
        static let enableModelCaching = true
        static let enableAutoRecovery = true
        static let enableDetailedLogging = true
    }
    
    // MARK: - Mood Detection Configuration
    enum Analysis {
        static let confidenceThreshold: Float = 0.80
        static let moodTransitionThreshold: Float = 0.65
        static let moodHistorySize = 10
        static let consecutiveLowConfidenceLimit = 3
        static let moodUpdateInterval: TimeInterval = 2.0
        static let moodStabilityFactor: Float = 0.7
        static let probabilityHistorySize = 5
        static let neutralFallbackThreshold: Float = 0.5
    }
}

// MARK: - Model Loading Helper
extension MLConfig {
    static func loadModel<T: MLModel>(_ asset: ModelAsset) throws -> T {
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