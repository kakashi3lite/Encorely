import Foundation
import Observation
import os.log
import SwiftUI

/// Detects mood from audio features and maintains mood history.
/// Uses rule-based scoring of energy, valence, tempo, and acousticness.
@Observable
final class MoodEngine: @unchecked Sendable {
    // MARK: - Observable State

    private(set) var currentMood: Mood = .happy
    private(set) var moodConfidence: Float = 0.0
    private(set) var recentMoods: [Mood] = []
    private(set) var moodDistribution: [Mood: Float] = [:]
    private(set) var isDetecting = false
    var adaptToContext = true

    private let logger = Logger(subsystem: "com.encorely", category: "MoodEngine")
    private let confidenceThreshold: Float = 0.15
    private let stabilityFactor: Float = 0.7
    private let maxRecentMoods = 20

    // MARK: - Init

    init() {
        initializeDistribution()
    }

    // MARK: - Public API

    /// Detects mood from a set of audio features.
    /// Returns the mood and confidence. Also records the result internally.
    func detectMood(from features: AudioFeatures) -> (mood: Mood, confidence: Float) {
        var scores: [(Mood, Float)] = Mood.allCases.map { mood in
            (mood, score(for: mood, features: features))
        }

        // Apply time-of-day bias if enabled
        if adaptToContext {
            applyTimeOfDayBias(&scores)
        }

        scores.sort { $0.1 > $1.1 }

        let best = scores.first ?? (.happy, 0.5)
        let total = scores.reduce(Float(0)) { $0 + $1.1 }
        let confidence = total > 0 ? best.1 / total : 0.5

        updateState(mood: best.0, confidence: confidence)
        return (best.0, confidence)
    }

    /// Generates a suggested playlist name based on current mood and time.
    func suggestPlaylistName() -> String {
        let descriptor = currentMood.keywords.randomElement() ?? currentMood.rawValue
        let timePrefix: String = switch TimeContext.current {
        case .morning:   ["Morning", "Sunrise", "Dawn"].randomElement()!
        case .afternoon: ["Afternoon", "Midday"].randomElement()!
        case .evening:   ["Evening", "Sunset", "Dusk"].randomElement()!
        case .night:     ["Night", "Midnight"].randomElement()!
        }

        return Bool.random()
            ? "\(timePrefix) \(descriptor.capitalized)"
            : "\(currentMood.rawValue) \(descriptor.capitalized)"
    }

    /// Returns the most frequently detected mood in recent history.
    func preferredMood() -> Mood? {
        var counts: [Mood: Int] = [:]
        for mood in recentMoods { counts[mood, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Resets internal state.
    func reset() {
        currentMood = .happy
        moodConfidence = 0.0
        recentMoods.removeAll()
        initializeDistribution()
    }

    // MARK: - Scoring

    /// Computes a raw score for a given mood based on audio features.
    /// Higher is a better match.
    private func score(for mood: Mood, features: AudioFeatures) -> Float {
        switch mood {
        case .energetic:
            return clamp(
                features.energy * 0.4
                + (features.tempo / 180.0) * 0.3
                + features.danceability * 0.3
            )
        case .relaxed:
            return clamp(
                (1.0 - features.energy) * 0.4
                + features.acousticness * 0.3
                + clamp(1.0 - features.tempo / 120.0) * 0.3
            )
        case .happy:
            return clamp(
                features.valence * 0.4
                + features.energy * 0.3
                + features.danceability * 0.3
            )
        case .melancholic:
            return clamp(
                (1.0 - features.valence) * 0.4
                + (1.0 - features.energy) * 0.3
                + features.acousticness * 0.3
            )
        case .focused:
            return clamp(
                features.instrumentalness * 0.4
                + (1.0 - features.speechiness) * 0.3
                + (0.5 - abs(0.5 - features.energy)) * 2.0 * 0.3
            )
        case .angry:
            return clamp(
                features.energy * 0.35
                + (1.0 - features.valence) * 0.35
                + (features.tempo / 180.0) * 0.3
            )
        }
    }

    private func clamp(_ value: Float) -> Float {
        min(1.0, max(0.0, value))
    }

    // MARK: - Time-of-Day Bias

    private func applyTimeOfDayBias(_ scores: inout [(Mood, Float)]) {
        let bias: Float = 0.08
        let context = TimeContext.current

        let boostMap: [TimeContext: Set<Mood>] = [
            .morning:   [.energetic, .focused],
            .afternoon: [.happy, .focused],
            .evening:   [.relaxed, .melancholic],
            .night:     [.melancholic, .relaxed],
        ]

        guard let boostSet = boostMap[context] else { return }
        scores = scores.map { (mood, s) in
            boostSet.contains(mood) ? (mood, s + bias) : (mood, s)
        }
    }

    // MARK: - State Management

    private func updateState(mood: Mood, confidence: Float) {
        guard confidence >= confidenceThreshold else { return }

        let shouldSwitch = currentMood != mood && confidence > moodConfidence * stabilityFactor
        if shouldSwitch || moodConfidence == 0 {
            currentMood = mood
            moodConfidence = confidence
        } else if currentMood == mood && confidence > moodConfidence {
            moodConfidence = confidence
        }

        recentMoods.insert(mood, at: 0)
        if recentMoods.count > maxRecentMoods {
            recentMoods.removeLast()
        }

        updateDistribution(mood: mood, confidence: confidence)
    }

    private func initializeDistribution() {
        moodDistribution = Dictionary(uniqueKeysWithValues: Mood.allCases.map { ($0, Float(0)) })
    }

    private func updateDistribution(mood: Mood, confidence: Float) {
        let decay: Float = 0.95
        for key in moodDistribution.keys { moodDistribution[key] = (moodDistribution[key] ?? 0) * decay }
        moodDistribution[mood, default: 0] += confidence * 0.5
        let total = moodDistribution.values.reduce(0, +)
        guard total > 0 else { return }
        for key in moodDistribution.keys { moodDistribution[key] = (moodDistribution[key] ?? 0) / total }
    }
}
