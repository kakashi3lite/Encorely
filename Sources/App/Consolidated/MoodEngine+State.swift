//  MoodEngine+State.swift
//  State management & distribution updates.

import Foundation

extension MoodEngine {
    func updateMood(_ newMood: Mood, confidence: Float) {
        guard confidence >= confidenceThreshold else { return }
        let shouldChange = currentMood != newMood && (confidence > moodConfidence * moodStabilityFactor)
        if shouldChange || currentMood == .neutral {
            DispatchQueue.main.async {
                self.currentMood = newMood
                self.moodConfidence = confidence
                self.updateRecentMoods(with: newMood)
                self.updateMoodDistribution(with: newMood, confidence: confidence)
            }
        } else if currentMood == newMood, confidence > moodConfidence {
            DispatchQueue.main.async { self.moodConfidence = confidence }
        }
    }

    func updateRecentMoods(with mood: Mood) {
        recentMoods.insert(mood, at: 0)
        if recentMoods.count > maxRecentMoods { recentMoods.removeLast() }
    }

    func updateMoodDistribution(with mood: Mood, confidence: Float) {
        let decay: Float = 0.95
        for key in moodDistribution.keys {
            moodDistribution[key] = (moodDistribution[key] ?? 0) * decay
        }
        moodDistribution[mood] = (moodDistribution[mood] ?? 0) + (confidence * 0.5)
        let total = moodDistribution.values.reduce(0, +)
        guard total > 0 else { return }
        for key in moodDistribution.keys {
            moodDistribution[key] = (moodDistribution[key] ?? 0) / total
        }
    }

    func getPreferredMood() -> Mood? {
        var counts: [Mood: Int] = [:]
        for m in recentMoods {
            counts[m, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    func registerExternalMoodHint(_ mood: Mood, weight: Float) {
        let w = max(0, min(1, weight))
        guard w > 0 else { return }
        moodDistribution[mood] = min(1, (moodDistribution[mood] ?? 0) + w * 0.1)
        for key in moodDistribution.keys where key != mood {
            moodDistribution[key] = max(
                0,
                (moodDistribution[key] ?? 0) * 0.98
            )
        }
        let total = moodDistribution.values.reduce(0, +)
        if total >
            0
        { for key in moodDistribution.keys {
            moodDistribution[key] = (moodDistribution[key] ?? 0) / total
        } }
        if moodConfidence < 0.5 || w > 0.3, currentMood != mood {
            currentMood = mood
            moodConfidence = min(1, max(moodConfidence, w * 0.8 + 0.2))
        }
    }
}
