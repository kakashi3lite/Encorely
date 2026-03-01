import Foundation
import Testing
@testable import Encorely

/// Tests for ViewModels.
struct ViewModelTests {
    // MARK: - LibraryViewModel

    @Test("LibraryViewModel sorts by newest first")
    func sortNewest() {
        let vm = LibraryViewModel()
        let older = Mixtape(title: "Old")
        let newer = Mixtape(title: "New")
        // Simulate older date
        older.createdDate = Date(timeIntervalSinceNow: -3600)

        let sorted = vm.sorted([older, newer], by: .newest)
        #expect(sorted.first?.title == "New")
    }

    @Test("LibraryViewModel sorts alphabetically")
    func sortAlphabetical() {
        let vm = LibraryViewModel()
        let b = Mixtape(title: "Beta")
        let a = Mixtape(title: "Alpha")

        let sorted = vm.sorted([b, a], by: .alphabetical)
        #expect(sorted.first?.title == "Alpha")
    }

    @Test("LibraryViewModel sorts by most played")
    func sortMostPlayed() {
        let vm = LibraryViewModel()
        let popular = Mixtape(title: "Popular")
        popular.playCount = 50
        let unpopular = Mixtape(title: "Unpopular")
        unpopular.playCount = 2

        let sorted = vm.sorted([unpopular, popular], by: .mostPlayed)
        #expect(sorted.first?.title == "Popular")
    }

    // MARK: - PlayerViewModel

    @Test("PlayerViewModel reflects playback service state")
    func playerViewModelReflects() {
        let service = AudioPlaybackService()
        let vm = PlayerViewModel(playbackService: service)

        #expect(vm.songTitle == "Not Playing")
        #expect(vm.artistName == "")
        #expect(vm.isPlaying == false)
        #expect(vm.progress == 0)
    }

    @Test("PlayerViewModel formats time correctly")
    func playerTimeFormat() {
        let service = AudioPlaybackService()
        let vm = PlayerViewModel(playbackService: service)

        // Default is 0:00
        #expect(vm.currentTimeFormatted == "0:00")
        #expect(vm.remainingTimeFormatted == "-0:00")
    }

    // MARK: - InsightsViewModel

    @Test("InsightsViewModel computes dominant mood")
    func insightsDominant() {
        let vm = InsightsViewModel()
        let snapshots = [
            MoodSnapshot(mood: .happy, confidence: 0.8),
            MoodSnapshot(mood: .happy, confidence: 0.9),
            MoodSnapshot(mood: .relaxed, confidence: 0.7),
        ]
        let dominant = vm.dominantMood(from: snapshots)
        #expect(dominant == .happy)
    }

    @Test("InsightsViewModel mood frequency percentages sum to 1.0")
    func insightsFrequency() {
        let vm = InsightsViewModel()
        let snapshots = [
            MoodSnapshot(mood: .happy, confidence: 0.8),
            MoodSnapshot(mood: .relaxed, confidence: 0.7),
            MoodSnapshot(mood: .happy, confidence: 0.9),
            MoodSnapshot(mood: .focused, confidence: 0.6),
        ]
        let freq = vm.moodFrequency(from: snapshots)
        let total = freq.reduce(0.0) { $0 + $1.percentage }
        #expect(abs(total - 1.0) < 0.01)
    }

    @Test("InsightsViewModel empty input returns empty")
    func insightsEmpty() {
        let vm = InsightsViewModel()
        #expect(vm.dominantMood(from: []) == nil)
        #expect(vm.moodFrequency(from: []).isEmpty)
        #expect(vm.groupByDay([]).isEmpty)
    }
}
