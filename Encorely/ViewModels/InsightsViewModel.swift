import Foundation
import Observation
import SwiftData

/// Provides computed insights from mood snapshots and user profile data.
@Observable
final class InsightsViewModel {
    /// Computes the most common mood from a list of snapshots.
    func dominantMood(from snapshots: [MoodSnapshot]) -> Mood? {
        var counts: [Mood: Int] = [:]
        for snapshot in snapshots {
            counts[snapshot.mood, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Groups snapshots by day for trend display.
    func groupByDay(_ snapshots: [MoodSnapshot]) -> [(date: Date, moods: [MoodSnapshot])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: snapshots) { snapshot in
            calendar.startOfDay(for: snapshot.timestamp)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, moods: $0.value) }
    }

    /// Returns mood frequency as percentages.
    func moodFrequency(from snapshots: [MoodSnapshot]) -> [(mood: Mood, percentage: Double)] {
        guard !snapshots.isEmpty else { return [] }
        var counts: [Mood: Int] = [:]
        for snapshot in snapshots {
            counts[snapshot.mood, default: 0] += 1
        }
        let total = Double(snapshots.count)
        return counts.map { (mood: $0.key, percentage: Double($0.value) / total) }
            .sorted { $0.percentage > $1.percentage }
    }
}
