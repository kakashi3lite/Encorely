//
//  RecommendationEngine.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Combine
import CoreML
import Foundation
import os.log

class RecommendationEngine: ObservableObject {
    // MARK: - Properties

    @Published private(set) var currentRecommendations: [Song] = []
    @Published private(set) var isGenerating = false

    // State management
    private var currentMood: Mood = .neutral
    private var currentPersonality: PersonalityType = .explorer
    private var currentBigFive: BigFiveProfile? // Hybrid profile
    private var backgroundTasks: Set<Task<Void, Never>> = []

    // Caching
    private var recommendationCache: [String: [Song]] = [:]
    private let cacheQueue = DispatchQueue(label: "com.aimixtapes.recommendationcache")
    private let maxCacheSize = 50

    // ML Models
    private var personalityModel: MLModel?
    private var recommendationModel: MLModel?
    private let modelQueue = DispatchQueue(label: "com.aimixtapes.recommendation", qos: .userInitiated)

    // Error handling
    private let errorSubject = PassthroughSubject<AppError, Never>()
    var errorPublisher: AnyPublisher<AppError, Never> {
        errorSubject.eraseToAnyPublisher()
    }

    // Logging
    private let logger = Logger(subsystem: "com.aimixtapes.ai", category: "RecommendationEngine")

    // MARK: - Initialization

    init() {
        setupModels()
    }

    // MARK: - Public Interface

    func updateMood(_ mood: Mood) { currentMood = mood; invalidateCache() }
    func updatePersonality(_ personality: PersonalityType) { currentPersonality = personality; invalidateCache() }
    func updateBigFiveProfile(_ profile: BigFiveProfile) {
        currentBigFive = profile
        currentPersonality = profile.mappedPersonalityType
        invalidateCache()
    }

    func getRecommendations(forMood mood: Mood, basedOn songs: [Song]) async throws -> [Song] {
        isGenerating = true
        defer { isGenerating = false }

        // Check cache first
        let cacheKey = generateCacheKey(mood: mood, songs: songs)
        if let cached = checkCache(for: cacheKey) {
            logger.info("Returning cached recommendations for mood: \(mood.rawValue)")
            return cached
        }

        do {
            let recommendations = try await generateRecommendations(
                mood: mood,
                songs: songs,
                personality: currentPersonality
            )

            // Cache results
            cacheRecommendations(recommendations, for: cacheKey)

            return recommendations
        } catch {
            handleError(error)
            throw error
        }
    }

    func clearCache() {
        cacheQueue.async {
            self.recommendationCache.removeAll()
            self.logger.info("Recommendation cache cleared")
        }
    }

    func pauseBackgroundTasks() {
        backgroundTasks.forEach { $0.cancel() }
        backgroundTasks.removeAll()
    }

    func releaseResources() {
        modelQueue.async {
            self.personalityModel = nil
            self.recommendationModel = nil
            self.logger.info("Released recommendation models")
        }
    }

    // MARK: - Private Implementation

    private func setupModels() {
        modelQueue.async {
            do {
                self.personalityModel = try MLConfig.loadModel(.personalityPredictor)
                self.recommendationModel = try MLConfig.loadModel(.audioFeatures)
                self.logger.info("Recommendation models loaded successfully")
            } catch {
                self.handleError(error)
            }
        }
    }

    private func generateRecommendations(
        mood: Mood,
        songs: [Song],
        personality: PersonalityType
    ) async throws -> [Song] {
        guard let model = recommendationModel else {
            throw AppError.modelNotReady
        }

        // Extract features from input songs
        let features = try await extractFeatures(from: songs)

        // Generate recommendations based on mood and personality
        let recommendations = try await generatePersonalizedRecommendations(
            features: features,
            mood: mood,
            personality: personality
        )

        // Validate recommendations
        guard !recommendations.isEmpty else {
            throw AppError.insufficientData
        }

        // Log success
        logger.info("Generated \(recommendations.count) recommendations for mood: \(mood.rawValue)")
        AILogger.shared.logInference(
            model: "RecommendationEngine",
            duration: 0,
            success: true
        )

        return recommendations
    }

    private func extractFeatures(from songs: [Song]) async throws -> [AudioFeatures] {
        var features: [AudioFeatures] = []

        for song in songs {
            if let cached = song.audioFeatures {
                features.append(cached)
            } else {
                // Extract features if not cached
                let audioURL = song.audioURL
                let audioFeatures = try await AudioAnalysisService().analyzeAudioFile(url: audioURL)
                song.audioFeatures = audioFeatures
                features.append(audioFeatures)
            }
        }

        return features
    }

    private func generatePersonalizedRecommendations(
        features: [AudioFeatures],
        mood: Mood,
        personality: PersonalityType
    ) async throws -> [Song] {
        let filtered = filterByPersonality(features, personality: personality)
        let weights = currentBigFive?.audioPreferenceWeights
        let scored = scoreByMood(filtered, targetMood: mood, weights: weights)
        return scored.sorted { $0.score > $1.score }.prefix(10).compactMap(\.song)
    }

    private func filterByPersonality(
        _ features: [AudioFeatures],
        personality: PersonalityType
    ) -> [(song: Song, features: AudioFeatures)] {
        switch personality {
        case .explorer:
            return features.shuffled().map { ($0.song, $0) }
        case .enthusiast:
            return features.filter { $0.energy > 0.6 || $0.danceability > 0.6 }.map { ($0.song, $0) }
        case .curator, .planner:
            return features.filter { (0.4...0.7).contains(Double($0.valence)) && (0.3...0.7).contains(Double($0.danceability)) }.map { ($0.song, $0) }
        case .creative:
            return features.filter { $0.instrumentalness > 0.5 || $0.liveness > 0.5 }.map { ($0.song, $0) }
        case .ambient:
            return features.filter { $0.energy < 0.5 && $0.speechiness < 0.5 }.map { ($0.song, $0) }
        case .balanced, .neutral, .analyzer, .social:
            return features.map { ($0.song, $0) }
        }
    }

    private func scoreByMood(
        _ features: [(song: Song, features: AudioFeatures)],
        targetMood: Mood,
        weights: AudioPreferenceWeights?
    ) -> [(song: Song, score: Float)] {
        features.map { pair in
            let base = calculateMoodScore(features: pair.features, targetMood: targetMood)
            if let w = weights {
                let energyAdj = Float(w.energy) * pair.features.energy
                let tempoAdj = Float(w.tempo) * min(max(pair.features.tempo / 200.0, 0), 1)
                let acousticAdj = Float(w.acousticness) * pair.features.acousticness
                let approxComplexity = 0.6 * (1 - pair.features.danceability) + 0.4 * pair.features.instrumentalness
                let complexityAdj = Float(w.complexity) * approxComplexity
                let hybrid = 0.7 * base + 0.3 * (0.35 * energyAdj + 0.25 * complexityAdj + 0.25 * tempoAdj + 0.15 * acousticAdj)
                return (pair.song, hybrid)
            }
            return (pair.song, base)
        }
    }

    private func calculateMoodScore(features: AudioFeatures, targetMood: Mood) -> Float {
        switch targetMood {
        case .energetic:
            let tempoScore = min(max(features.tempo / 200.0, 0), 1)
            return 0.5 * features.energy + 0.3 * features.danceability + 0.2 * tempoScore
        case .relaxed:
            let lowEnergy = 1 - features.energy
            return 0.5 * lowEnergy + 0.3 * features.acousticness + 0.2 * (1 - features.liveness)
        case .happy:
            return 0.5 * features.valence + 0.3 * features.energy + 0.2 * features.danceability
        case .melancholic:
            let lowValence = 1 - features.valence
            let lowTempo = 1 - min(max(features.tempo / 200.0, 0), 1)
            return 0.5 * lowValence + 0.3 * lowTempo + 0.2 * (1 - features.energy)
        case .focused:
            let steadiness = 1 - abs(features.energy - 0.5) * 2
            return max(0, steadiness) * 0.5 + 0.3 * (1 - features.liveness) + 0.2 * (1 - features.speechiness)
        case .romantic:
            return 0.5 * features.valence + 0.3 * features.acousticness + 0.2 * (1 - features.speechiness)
        case .angry:
            let lowValence = 1 - features.valence
            return 0.6 * features.energy + 0.4 * lowValence
        case .neutral:
            return 0.5
        }
    }

    private func generateCacheKey(mood: Mood, songs: [Song]) -> String {
        let songIds = songs.map(\.id.uuidString).joined(separator: "-")
        return "\(mood.rawValue)-\(songIds)"
    }

    private func checkCache(for key: String) -> [Song]? {
        cacheQueue.sync {
            recommendationCache[key]
        }
    }

    private func cacheRecommendations(_ recommendations: [Song], for key: String) {
        cacheQueue.async {
            // Implement LRU cache eviction if needed
            if self.recommendationCache.count >= self.maxCacheSize {
                self.recommendationCache.removeValue(forKey: self.recommendationCache.keys.first!)
            }

            self.recommendationCache[key] = recommendations
        }
    }

    private func invalidateCache() {
        cacheQueue.async {
            self.recommendationCache.removeAll()
        }
    }

    private func handleError(_ error: Error) {
        let appError = error as? AppError ?? .aiPredictionFailed(error)
        errorSubject.send(appError)

        logger.error("Recommendation error: \(appError.localizedDescription)")
        AILogger.shared.logError(model: "RecommendationEngine", error: appError)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let recommendationsDidUpdate = Notification.Name("recommendationsDidUpdate")
}

// MARK: - Async Extensions

extension Sequence {
    func concurrentMap<T>(
        _ transform: @escaping (Element) async throws -> T) async throws -> [T]
    {
        let tasks = map { element in
            Task {
                try await transform(element)
            }
        }

        return try await tasks.map { task in
            try await task.value
        }
    }
}

/// Extension to MixTape for recommendation-specific functionality
extension MixTape {
    /// Returns a list of songs with optimal order for the current mood
    func getReorderedSongsForMood(_ mood: Mood) -> [Song] {
        // In a real implementation, this would analyze each song's characteristics
        // and reorder them based on the desired mood progression

        switch mood {
        case .energetic:
            // For energetic mood, start with high energy and maintain it
            songsArray.sorted { _, _ in
                // This would actually sort by tempo/energy in a real implementation
                Bool.random()
            }

        case .relaxed:
            // For relaxed mood, start mellow and get progressively more relaxed
            songsArray.sorted { _, _ in
                // This would actually sort by tempo/energy in a real implementation
                Bool.random()
            }

        default:
            // Default to original order for other moods
            songsArray
        }
    }

    /// Analyzes the audio characteristics of the mixtape to determine mood compatibility
    func getMoodCompatibility() -> [Mood: Float] {
        // In a real implementation, this would analyze audio features
        // For now, return random values for demonstration

        var compatibility: [Mood: Float] = [:]

        for mood in Mood.allCases {
            compatibility[mood] = Float.random(in: 0 ... 1)
        }

        return compatibility
    }
}
