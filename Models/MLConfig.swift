import CoreML
import Vision

/// Configuration for Core ML models and AI processing
enum MLConfig {
    // MARK: - Model Versioning
    static let emotionModelVersion = "v1.0.0"
    static let audioFeatureModelVersion = "v1.0.0"
    static let personalityModelVersion = "v1.0.0"
    
    // MARK: - Performance Settings
    static let computeUnits: MLComputeUnits = .all
    static let preferredMemoryFootprint: MLModelConfiguration.PreferredMemoryFootprint = .reduced
    static let allowLowPrecisionAccumulationOnGPU = true
    static let allowBackgroundProcessing = true
    
    // MARK: - Thresholds
    struct Thresholds {
        static let minimumEmotionConfidence: Float = 0.6
        static let minimumFeatureConfidence: Float = 0.5
        static let minimumSampleLength: Int = 1024
        static let minimumAudioDuration: TimeInterval = 3.0
        static let maximumInferenceTime: TimeInterval = 0.1 // seconds
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
        static let retryDelay: TimeInterval = 0.5
        static let useGracefulDegradation = true
        
        static func shouldRetry(_ error: Error, attempts: Int) -> Bool {
            guard attempts < maxRetryAttempts else { return false }
            return (error as NSError).domain == MLModelErrorDomain
        }
    }
    
    // MARK: - Model Paths
    enum ModelAsset: String {
        case emotionClassifier = "EmotionClassifier"
        case audioFeatures = "AudioFeatures"
        case personalityPredictor = "PersonalityPredictor"
        
        var url: URL? {
            Bundle.main.url(forResource: rawValue, withExtension: "mlmodelc")
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