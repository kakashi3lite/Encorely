import Foundation
import Observation
import os.log

/// Generates song recommendations and mixtape orderings
/// based on mood targets and personality preferences.
///
/// Combines MoodEngine scores with PersonalityEngine weights
/// to produce personalized track lists.
@Observable
final class RecommendationEngine: @unchecked Sendable {
    // MARK: - Observable State

    /// Whether a generation is in progress.
    private(set) var isGenerating: Bool = false

    // MARK: - Dependencies

    private let moodEngine: MoodEngine
    private let personalityEngine: PersonalityEngine
    private let logger = Logger(subsystem: "com.encorely", category: "RecommendationEngine")

    // MARK: - Cache

    private var cache: [String: [ScoredSong]] = [:]
    private let maxCacheEntries = 50

    // MARK: - Init

    init(moodEngine: MoodEngine, personalityEngine: PersonalityEngine) {
        self.moodEngine = moodEngine
        self.personalityEngine = personalityEngine
    }

    // MARK: - Public API

    /// Scores and ranks songs for a target mood.
    /// Returns songs sorted best-match-first.
    func recommend(
        songs: [Song],
        targetMood: Mood,
        limit: Int = 20
    ) -> [Song] {
        isGenerating = true
        defer { isGenerating = false }

        let cacheKey = "\(targetMood.rawValue)-\(songs.count)"
        if let cached = cache[cacheKey] {
            logger.info("Cache hit for mood: \(targetMood.rawValue)")
            return cached.prefix(limit).map(\.song)
        }

        let scored = songs.compactMap { song -> ScoredSong? in
            guard let features = song.audioFeatures else { return nil }
            let moodScore = moodMatch(features: features, target: targetMood)
            let personalityWeight = personalityMultiplier(for: features)
            let finalScore = moodScore * personalityWeight
            return ScoredSong(song: song, score: finalScore)
        }
        .sorted { $0.score > $1.score }

        // Cache the result
        if cache.count >= maxCacheEntries { cache.removeAll() }
        cache[cacheKey] = scored

        logger.info("Generated \(scored.count) recommendations for \(targetMood.rawValue)")
        return Array(scored.prefix(limit).map(\.song))
    }

    /// Builds a new mixtape track list for a given mood.
    /// Filters available songs, scores them, and returns the top matches.
    func buildMixtapeTrackList(
        from availableSongs: [Song],
        mood: Mood,
        count: Int = 12
    ) -> [Song] {
        let ranked = recommend(songs: availableSongs, targetMood: mood, limit: count)

        // Assign positions
        for (index, song) in ranked.enumerated() {
            song.position = index
            song.moodTag = mood.rawValue
        }

        return ranked
    }

    /// Invalidates the recommendation cache. Call when mood or personality changes.
    func invalidateCache() {
        cache.removeAll()
    }

    // MARK: - Scoring

    /// How well a song's features match the target mood (0.0–1.0).
    private func moodMatch(features: AudioFeatures, target: Mood) -> Float {
        switch target {
        case .energetic:
            return weighted(
                (features.energy, 0.4),
                (features.tempo / 180.0, 0.3),
                (features.danceability, 0.3)
            )
        case .relaxed:
            return weighted(
                (1.0 - features.energy, 0.4),
                (features.acousticness, 0.3),
                (clamp(1.0 - features.tempo / 120.0), 0.3)
            )
        case .happy:
            return weighted(
                (features.valence, 0.4),
                (features.energy, 0.3),
                (features.danceability, 0.3)
            )
        case .melancholic:
            return weighted(
                (1.0 - features.valence, 0.4),
                (1.0 - features.energy, 0.3),
                (features.acousticness, 0.3)
            )
        case .focused:
            return weighted(
                (features.instrumentalness, 0.4),
                (1.0 - features.speechiness, 0.3),
                ((0.5 - abs(0.5 - features.energy)) * 2.0, 0.3)
            )
        case .angry:
            return weighted(
                (features.energy, 0.35),
                (1.0 - features.valence, 0.35),
                (features.tempo / 180.0, 0.3)
            )
        }
    }

    /// Multiplier based on personality preferences.
    /// Explorers get variety boost, curators get consistency boost, etc.
    private func personalityMultiplier(for features: AudioFeatures) -> Float {
        switch personalityEngine.currentPersonality {
        case .explorer:
            // Slight random variance to encourage diversity
            return Float.random(in: 0.85...1.15)
        case .curator:
            return 1.0
        case .enthusiast:
            // Boost high-energy songs
            return features.energy > 0.6 ? 1.15 : 0.95
        case .analyzer:
            // Prefer instrumentals and complex tracks
            return features.instrumentalness > 0.5 ? 1.1 : 1.0
        case .balanced:
            return 1.0
        }
    }

    // MARK: - Helpers

    private func weighted(_ pairs: (Float, Float)...) -> Float {
        clamp(pairs.reduce(Float(0)) { $0 + $1.0 * $1.1 })
    }

    private func clamp(_ v: Float) -> Float {
        min(1.0, max(0.0, v))
    }
}

// MARK: - Internal Types

private struct ScoredSong {
    let song: Song
    let score: Float
}
