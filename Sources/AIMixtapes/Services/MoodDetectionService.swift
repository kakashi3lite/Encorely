import Foundation
import CoreML
import AVFoundation
import Combine

class MoodDetectionService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var currentMood: Mood = .neutral
    @Published private(set) var moodConfidence: Float = 0.0
    @Published private(set) var moodHistory: [MoodSnapshot] = []
    
    // MARK: - Private Properties
    private let audioAnalysis: AudioAnalysisService
    private let aiLogger = AILogger.shared
    private let moodEngine = MLConfig.loadMoodModel()
    
    private var moodSubscriptions = Set<AnyCancellable>()
    private var analysisTimer: Timer?
    private let analysisInterval: TimeInterval = 5.0
    
    private var audioFeatures: AudioFeatures?
    private var recentMoods: [Mood] = []
    private let moodBufferSize = 5
    
    // Mood transition thresholds
    private let confidenceThreshold: Float = 0.7
    private let transitionThreshold: Float = 0.3
    
    // MARK: - Initialization
    
    init(audioAnalysis: AudioAnalysisService = AudioAnalysisService()) {
        self.audioAnalysis = audioAnalysis
        setupAudioAnalysis()
        startMoodTracking()
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
                guard let self = self else { return }
                
                let snapshot = MoodSnapshot(mood: newMood,
                                         confidence: self.moodConfidence,
                                         timestamp: Date())
                self.moodHistory.append(snapshot)
                
                // Keep history manageable
                if self.moodHistory.count > 100 {
                    self.moodHistory.removeFirst()
                }
                
                // Log mood change
                self.aiLogger.logMoodTransition(from: self.currentMood,
                                              to: newMood,
                                              confidence: self.moodConfidence)
                
                // Notify observers
                NotificationCenter.default.post(
                    name: .moodDidChange,
                    object: newMood,
                    userInfo: ["confidence": self.moodConfidence]
                )
            }
            .store(in: &moodSubscriptions)
    }
    
    private func analyzeMood() {
        guard let features = audioFeatures else { return }
        
        // Prepare input for mood model
        let input = prepareMoodModelInput(from: features)
        
        // Get mood prediction
        do {
            let prediction = try moodEngine.prediction(input: input)
            let predictedMood = Mood(rawValue: prediction.mood) ?? .neutral
            let confidence = prediction.confidence[prediction.mood] ?? 0.0
            
            // Update mood buffer
            recentMoods.append(predictedMood)
            if recentMoods.count > moodBufferSize {
                recentMoods.removeFirst()
            }
            
            // Only update mood if we have stable detection
            if shouldUpdateMood(to: predictedMood, withConfidence: confidence) {
                updateMood(to: predictedMood, withConfidence: confidence)
            }
            
        } catch {
            aiLogger.logError(error, context: "Mood detection failed")
        }
    }
    
    private func prepareMoodModelInput(from features: AudioFeatures) -> MoodModelInput {
        // Normalize and prepare audio features
        let normalizedEnergy = normalize(features.energy, min: 0, max: 100)
        let normalizedTempo = normalize(features.tempo, min: 60, max: 180)
        let normalizedValence = features.valence
        
        return MoodModelInput(
            energy: normalizedEnergy,
            tempo: normalizedTempo,
            valence: normalizedValence,
            spectralCentroid: features.spectralCentroid,
            spectralRolloff: features.spectralRolloff,
            zeroCrossingRate: features.zeroCrossingRate
        )
    }
    
    private func shouldUpdateMood(to newMood: Mood, withConfidence confidence: Float) -> Bool {
        // Check if the new mood is stable
        let dominantMood = recentMoods.mostFrequent()
        
        // Require high confidence for mood changes
        if newMood != currentMood {
            return confidence >= confidenceThreshold && newMood == dominantMood
        }
        
        // Allow mood to persist with lower confidence
        return confidence >= transitionThreshold
    }
    
    private func updateMood(to newMood: Mood, withConfidence confidence: Float) {
        if newMood != currentMood || abs(confidence - moodConfidence) > 0.2 {
            currentMood = newMood
            moodConfidence = confidence
        }
    }
    
    private func normalize(_ value: Double, min: Double, max: Double) -> Double {
        return (value - min) / (max - min)
    }
}

// MARK: - Supporting Types

struct MoodSnapshot {
    let mood: Mood
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