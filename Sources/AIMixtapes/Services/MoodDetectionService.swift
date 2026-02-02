import Foundation
import CoreML
import AVFoundation
import Combine
import os

class MoodDetectionService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var currentMood: Asset.MoodColor = .neutral
    @Published private(set) var moodConfidence: Float = 0.0
    @Published private(set) var moodHistory: [MoodSnapshot] = []
    
    // MARK: - Private Properties
    private let audioAnalysis: AudioAnalysisService
    private let aiLogger = AILogger.shared
    private let moodEngine = MLConfig.loadMoodModel()
    private let logger = Logger(subsystem: "com.aimixtapes", category: "MoodDetection")
    
    private var moodSubscriptions = Set<AnyCancellable>()
    private var analysisTimer: Timer?
    private var statisticsTimer: Timer?  // Fixed: Store timer reference to properly invalidate
    private let analysisInterval: TimeInterval = MLConfig.Analysis.moodUpdateInterval
    
    private var audioFeatures: AudioFeatures?
    private var recentMoods: [Asset.MoodColor] = []
    private let moodBufferSize = MLConfig.Analysis.moodHistorySize
    
    // Cached mood distribution to avoid recalculating on every call
    private var cachedMoodDistribution: [Asset.MoodColor: Int] = [:]
    
    // Mood transition thresholds
    private let confidenceThreshold: Float = MLConfig.Analysis.confidenceThreshold
    private let moodStabilityFactor: Float = MLConfig.Analysis.moodStabilityFactor
    
    // MARK: - Initialization
    
    init(audioAnalysis: AudioAnalysisService = AudioAnalysisService()) {
        self.audioAnalysis = audioAnalysis
        setupAudioAnalysis()
        startMoodTracking()
    }
    
    // MARK: - Public Methods
    
    func startAnalysis() {
        analysisTimer?.invalidate()
        analysisTimer = Timer.scheduledTimer(
            withTimeInterval: analysisInterval,
            repeats: true
        ) { [weak self] _ in
            self?.analyzeMood()
        }
    }
    
    func stopAnalysis() {
        analysisTimer?.invalidate()
        analysisTimer = nil
    }
    
    func getMoodTransitionProbability(to targetMood: Asset.MoodColor) -> Float {
        guard let lastMood = moodHistory.last?.mood else { return 0.5 }
        
        // Calculate based on historical transitions
        let transitions = moodHistory.windows(ofCount: 2)
            .filter { $0.first?.mood == lastMood }
        
        let targetTransitions = transitions.filter { $0.last?.mood == targetMood }
        
        guard !transitions.isEmpty else { return 0.5 }
        return Float(targetTransitions.count) / Float(transitions.count)
    }
    
    // MARK: - Private Methods
    
    private func setupAudioAnalysis() {
        // Subscribe to audio features updates
        audioAnalysis.audioFeaturesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] features in
                self?.audioFeatures = features
                self?.analyzeMood()
            }
            .store(in: &moodSubscriptions)
            
        // Subscribe to mood changes
        audioAnalysis.moodPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mood in
                self?.handleMoodUpdate(mood)
            }
            .store(in: &moodSubscriptions)
    }
    
    private func startMoodTracking() {
        // Fixed: Store timer reference to properly clean up
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateMoodStatistics()
        }
    }
    
    deinit {
        // Fixed: Properly clean up timers to prevent memory leaks
        analysisTimer?.invalidate()
        statisticsTimer?.invalidate()
        moodSubscriptions.removeAll()
    }
    
    private func analyzeMood() {
        guard let features = audioFeatures else { return }
        
        // Get mood prediction
        let (predictedMood, confidence) = features.predictMood()
        
        // Update mood buffer
        recentMoods.append(predictedMood)
        if recentMoods.count > moodBufferSize {
            recentMoods.removeFirst()
        }
        
        // Only update mood if we have stable detection
        if shouldUpdateMood(to: predictedMood, withConfidence: confidence) {
            updateMood(to: predictedMood, withConfidence: confidence)
        }
    }
    
    private func shouldUpdateMood(
        to newMood: Asset.MoodColor,
        withConfidence confidence: Float
    ) -> Bool {
        // Require higher confidence for mood changes
        let requiredConfidence = newMood == currentMood ?
            confidenceThreshold :
            confidenceThreshold * 1.2
        
        // Check if mood is stable
        let moodStability = Float(recentMoods.filter { $0 == newMood }.count) /
            Float(recentMoods.count)
        
        return confidence >= requiredConfidence &&
               moodStability >= moodStabilityFactor
    }
    
    private func updateMood(
        to newMood: Asset.MoodColor,
        withConfidence confidence: Float
    ) {
        let oldMood = currentMood
        currentMood = newMood
        moodConfidence = confidence
        
        // Add to history
        let snapshot = MoodSnapshot(
            mood: newMood,
            confidence: confidence,
            timestamp: Date()
        )
        moodHistory.append(snapshot)
        
        // Update cached distribution incrementally
        cachedMoodDistribution[newMood, default: 0] += 1
        
        // Maintain history size
        if moodHistory.count > MLConfig.Analysis.moodHistorySize {
            let removedSnapshot = moodHistory.removeFirst()
            // Update cached distribution when removing old entries
            if let count = cachedMoodDistribution[removedSnapshot.mood], count > 0 {
                cachedMoodDistribution[removedSnapshot.mood] = count - 1
            }
        }
        
        // Log mood change
        aiLogger.logMoodTransition(
            from: oldMood,
            to: newMood,
            confidence: confidence
        )
        
        logger.info("Mood updated: \(oldMood) -> \(newMood) (confidence: \(confidence))")
        
        // Notify observers
        NotificationCenter.default.post(
            name: .moodDidChange,
            object: newMood,
            userInfo: ["confidence": confidence]
        )
    }
    
    private func updateMoodStatistics() {
        guard !moodHistory.isEmpty else { return }
        
        // Use cached distribution instead of recalculating
        // This is O(1) instead of O(n) since we maintain it incrementally
        let total = Float(moodHistory.count)
        cachedMoodDistribution.forEach { mood, count in
            let percentage = (Float(count) / total) * 100
            logger.info("Mood distribution - \(mood): \(String(format: "%.1f%%", percentage))")
        }
    }
    
    private func handleMoodUpdate(_ mood: Asset.MoodColor) {
        // Additional processing or validation can be added here
        if currentMood != mood {
            logger.info("External mood update received: \(mood)")
        }
    }
}

// MARK: - Supporting Types

struct MoodSnapshot {
    let mood: Asset.MoodColor
    let confidence: Float
    let timestamp: Date
}

struct AudioFeatures {
    let energy: Double
    let tempo: Double
    let valence: Double
    let spectralCentroid: Double
    let spectralRolloff: Double
    let zeroCrossingRate: Double
}

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
        let counts = self.reduce(into: [:]) { counts, element in
            counts[element, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

extension Notification.Name {
    static let moodDidChange = Notification.Name("moodDidChange")
}