import AVFoundation
import Combine
import CoreML
import Foundation
import os.signpost

class MoodDetectionService: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var currentMood: Mood = .neutral
    @Published private(set) var moodConfidence: Float = 0.0
    @Published private(set) var moodHistory: [MoodSnapshot] = []

    // MARK: - Private Properties

    private let audioAnalysis: AudioAnalysisService
    private let aiLogger = AILogger.shared
    private let moodEngine = MLConfig.loadMoodModel()
    private let logger = Logger(subsystem: "com.aimixtapes", category: "MoodDetection")

    // Dedicated inference queue with QoS for real-time processing
    private let inferenceQueue = DispatchQueue(
        label: "com.aimixtapes.inference",
        qos: .userInteractive,
        attributes: .concurrent
    )

    // Performance optimization
    private var modelCache: MLModelCache?
    private var predictionPool: MLDictionaryFeatureProvider?
    private var lastPredictionTime: TimeInterval = 0
    private var inferenceCount: Int = 0
    private let poolSize = 10

    private var moodSubscriptions = Set<AnyCancellable>()
    private var analysisTimer: Timer?
    private let analysisInterval: TimeInterval = 5.0

    private var audioFeatures: AudioFeatures?
    private var recentMoods: [Mood] = []
    private let moodBufferSize = 5

    // Mood transition thresholds
    private let confidenceThreshold: Float = 0.7
    private let transitionThreshold: Float = 0.3

    private var probabilityHistory = ProbabilityHistory(capacity: MLConfig.Analysis.probabilityHistorySize)
    private var lastMoodTransitionTime = Date()

    // Performance monitoring
    private let signposter = OSSignposter(subsystem: "com.aimixtapes", category: "MoodDetection")
    private static let moodAnalysisInterval = OSSignpostInterval(name: "Mood Analysis")
    private static let mlInferenceInterval = OSSignpostInterval(name: "ML Inference")

    // Performance metrics
    private var inferenceMetrics: [TimeInterval] = []
    private let maxMetricSamples = 100

    // MARK: - Initialization

    init(audioAnalysis: AudioAnalysisService = AudioAnalysisService()) {
        self.audioAnalysis = audioAnalysis
        setupAudioAnalysis()
        startMoodTracking()
        setupOptimizedInference()
    }

    // MARK: - Public Methods

    func startAnalysis() {
        analysisTimer?.invalidate()
        analysisTimer = Timer.scheduledTimer(withTimeInterval: analysisInterval, repeats: true) { [weak self] _ in
            self?.analyzeMood()
        }
    }

    func stopAnalysis() {
        analysisTimer?.invalidate()
        analysisTimer = nil
    }

    func getMoodTransitionProbability(to targetMood: Mood) -> Float {
        guard let lastMood = moodHistory.last?.mood else { return 0.5 }

        // Calculate based on historical transitions
        let transitions = moodHistory.windows(ofCount: 2)
            .filter { $0.first?.mood == lastMood }

        let targetTransitions = transitions.filter { $0.last?.mood == targetMood }

        guard !transitions.isEmpty else { return 0.5 }
        return Float(targetTransitions.count) / Float(transitions.count)
    }

    func getMoodDuration() -> TimeInterval? {
        guard let lastTransition = moodHistory.last?.timestamp else { return nil }
        return Date().timeIntervalSince(lastTransition)
    }

    // MARK: - Private Methods

    private func setupAudioAnalysis() {
        audioAnalysis.audioFeaturesPublisher
            .sink { [weak self] features in
                self?.audioFeatures = features
                self?.analyzeMood()
            }
            .store(in: &moodSubscriptions)
    }

    private func startMoodTracking() {
        // Track significant mood changes
        $currentMood
            .dropFirst()
            .sink { [weak self] newMood in
                guard let self else { return }

                let snapshot = MoodSnapshot(mood: newMood,
                                            confidence: moodConfidence,
                                            timestamp: Date())
                moodHistory.append(snapshot)

                // Keep history manageable
                if moodHistory.count > 100 {
                    moodHistory.removeFirst()
                }

                // Log mood change
                aiLogger.logMoodTransition(from: currentMood,
                                           to: newMood,
                                           confidence: moodConfidence)

                // Notify observers
                NotificationCenter.default.post(
                    name: .moodDidChange,
                    object: newMood,
                    userInfo: ["confidence": moodConfidence]
                )
            }
            .store(in: &moodSubscriptions)
    }

    private func setupOptimizedInference() {
        modelCache = try? MLModelCache(modelAsset: .emotionClassifier)
        setupPredictionPool()
    }

    private func setupPredictionPool() {
        // Pre-allocate feature providers for better performance
        let featureNames = ["energy", "tempo", "valence", "spectralCentroid", "spectralRolloff", "zeroCrossingRate"]
        predictionPool = MLDictionaryFeatureProvider(dictionary: featureNames.reduce(into: [:]) { dict, name in
            dict[name] = MLFeatureValue(double: 0.0)
        })
    }

    private func analyzeMood() {
        guard let features = audioFeatures else { return }

        let state = signposter.beginInterval(MoodDetectionService.moodAnalysisInterval)

        inferenceQueue.async { [weak self] in
            guard let self else { return }

            autoreleasepool {
                let mlState = self.signposter.beginInterval(MoodDetectionService.mlInferenceInterval)
                let inferenceStart = CACurrentMediaTime()

                do {
                    // Reuse prediction pool for better performance
                    if let pool = self.predictionPool {
                        self.updatePredictionPool(pool, with: features)
                        let prediction = try self.moodEngine.prediction(input: pool)
                        let inferenceTime = CACurrentMediaTime() - inferenceStart

                        self.updateInferenceMetrics(time: inferenceTime)

                        // Get prediction with confidence
                        let (predictedMood, confidence) = self.selectMoodFromPrediction(prediction)

                        DispatchQueue.main.async {
                            if self.shouldUpdateMood(to: predictedMood, withConfidence: confidence) {
                                self.updateMood(to: predictedMood, withConfidence: confidence)
                            }
                        }
                    }
                } catch {
                    self.logger.error("ML inference failed: \(error.localizedDescription)")
                }

                self.signposter.endInterval(MoodDetectionService.mlInferenceInterval, mlState)
                self.signposter.endInterval(MoodDetectionService.moodAnalysisInterval, state)
            }
        }
    }

    private func updatePredictionPool(_ pool: MLDictionaryFeatureProvider, with features: AudioFeatures) {
        // Update feature values in place to avoid allocations
        pool.dictionary["energy"] = MLFeatureValue(double: normalize(features.energy, min: 0, max: 100))
        pool.dictionary["tempo"] = MLFeatureValue(double: normalize(features.tempo, min: 60, max: 180))
        pool.dictionary["valence"] = MLFeatureValue(double: features.valence)
        pool.dictionary["spectralCentroid"] = MLFeatureValue(double: features.spectralCentroid)
        pool.dictionary["spectralRolloff"] = MLFeatureValue(double: features.spectralRolloff)
        pool.dictionary["zeroCrossingRate"] = MLFeatureValue(double: features.zeroCrossingRate)
    }

    private func selectMoodFromPrediction(_ prediction: MoodModelPrediction) -> (Mood, Float) {
        var bestMood = Mood.neutral
        var bestConfidence: Float = 0

        for (mood, confidence) in prediction.moodProbabilities {
            if let mood = Mood(rawValue: mood), confidence > bestConfidence {
                bestMood = mood
                bestConfidence = confidence
            }
        }

        return (bestMood, bestConfidence)
    }

    private func shouldUpdateMood(to newMood: Mood, withConfidence confidence: Float) -> Bool {
        // If same mood, allow update with lower confidence
        if newMood == currentMood {
            return confidence >= MLConfig.Analysis.moodTransitionThreshold
        }

        // Require higher confidence and stable history for mood changes
        let moodStability = probabilityHistory.getSmoothedConfidence(for: newMood)
        return confidence >= MLConfig.Analysis.confidenceThreshold &&
            moodStability >= MLConfig.Analysis.moodStabilityFactor
    }

    private func updateMood(to newMood: Mood, withConfidence confidence: Float) {
        if newMood != currentMood || abs(confidence - moodConfidence) > 0.2 {
            currentMood = newMood
            moodConfidence = confidence
        }
    }

    private func normalize(_ value: Double, min: Double, max: Double) -> Double {
        (value - min) / (max - min)
    }

    private func updateInferenceMetrics(time: TimeInterval) {
        inferenceMetrics.append(time)
        if inferenceMetrics.count > maxMetricSamples {
            inferenceMetrics.removeFirst()
        }

        // Log if average inference time exceeds threshold
        let avgInference = inferenceMetrics.reduce(0, +) / Double(inferenceMetrics.count)
        if avgInference > 0.01 { // 10ms threshold
            logger.warning("High inference latency: \(String(format: "%.2f", avgInference * 1000))ms")
        }
    }

    func getPerformanceMetrics() -> String {
        let avgInference = inferenceMetrics.reduce(0, +) / Double(inferenceMetrics.count)
        return """
        Mood Detection Performance:
        Average Inference Time: \(String(format: "%.2f", avgInference * 1000))ms
        Recent Samples: \(inferenceMetrics.count)
        Confidence: \(String(format: "%.2f", moodConfidence * 100))%
        """
    }

    private struct ProbabilityHistory {
        private var buffer: [(mood: Mood, confidence: Float)]
        private let capacity: Int
        private var currentIndex = 0

        init(capacity: Int) {
            self.capacity = capacity
            buffer = []
            buffer.reserveCapacity(capacity)
        }

        mutating func add(_ mood: Mood, confidence: Float) {
            if buffer.count < capacity {
                buffer.append((mood, confidence))
            } else {
                buffer[currentIndex] = (mood, confidence)
            }
            currentIndex = (currentIndex + 1) % capacity
        }

        func getSmoothedConfidence(for mood: Mood) -> Float {
            guard !buffer.isEmpty else { return 0 }

            // Apply exponential moving average
            let alpha: Float = 0.7 // Weight for most recent values
            var weightedSum: Float = 0
            var weightedCount: Float = 0
            var weight: Float = 1.0

            for entry in buffer.reversed() where entry.mood == mood {
                weightedSum += entry.confidence * weight
                weightedCount += weight
                weight *= (1 - alpha)
            }

            return weightedCount > 0 ? weightedSum / weightedCount : 0
        }

        func getConsecutiveLowConfidence() -> Int {
            var count = 0
            for entry in buffer.reversed() {
                if entry.confidence < MLConfig.Analysis.neutralFallbackThreshold {
                    count += 1
                } else {
                    break
                }
            }
            return count
        }
    }
}

// MARK: - Supporting Types

struct MoodSnapshot {
    let mood: Mood
    let confidence: Float
    let timestamp: Date
}

// AudioFeatures moved to App/Consolidated/AudioFeatures.swift to avoid duplication

struct MoodModelInput {
    let energy: Double
    let tempo: Double
    let valence: Double
    let spectralCentroid: Double
    let spectralRolloff: Double
    let zeroCrossingRate: Double
}

extension Array where Element: Hashable {
    func mostFrequent() -> Element? {
        let counts = reduce(into: [:]) { counts, element in
            counts[element, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

extension Notification.Name {
    static let moodDidChange = Notification.Name("moodDidChange")
}
