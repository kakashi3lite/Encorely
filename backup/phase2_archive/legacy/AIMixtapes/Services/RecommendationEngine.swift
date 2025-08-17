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
    private var mbtiProfile: MBTIProfile?
    private let sensorDataManager: SensorDataManager
    private var currentMood: Mood = .neutral
    private var currentPersonality: PersonalityType = .explorer
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

    init(mbtiProfile: MBTIProfile? = nil) {
        self.mbtiProfile = mbtiProfile
        sensorDataManager = SensorDataManager()
        setupSensorTracking()
        setupModels()
    }

    // MARK: - Public Interface

    func updateMood(_ mood: Mood) {
        currentMood = mood
        invalidateCache()
    }

    func updatePersonality(_ personality: PersonalityType) {
        currentPersonality = personality
        invalidateCache()
    }

    func updateMBTIProfile(_ profile: MBTIProfile) {
        mbtiProfile = profile
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
            // Extract features from input songs
            let features = try await extractFeatures(from: songs)

            // Get MBTI-adjusted preferences
            let preferences = getMBTIAdjustedPreferences()

            // Score and filter songs
            let recommendations = try await generatePersonalizedRecommendations(
                features: features,
                mood: mood,
                preferences: preferences
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

    private func setupSensorTracking() {
        sensorDataManager.startMonitoring()
    }

    private func extractFeatures(from songs: [Song]) async throws -> [AudioFeatures] {
        try await withThrowingTaskGroup(of: AudioFeatures?.self) { group in
            var features: [AudioFeatures] = []

            for song in songs {
                group.addTask {
                    if let cached = song.features {
                        return cached
                    } else {
                        let audioFeatures = try await self.analyzeAudio(for: song)
                        song.features = audioFeatures
                        return audioFeatures
                    }
                }
            }

            for try await feature in group {
                if let feature {
                    features.append(feature)
                }
            }

            return features
        }
    }

    private func analyzeAudio(for song: Song) async throws -> AudioFeatures {
        let service = AudioAnalysisService()
        return try await service.analyzeAudioFile(at: song.audioURL)
    }

    private func getMBTIAdjustedPreferences() -> AudioPreferences {
        // Get base preferences from MBTI profile or use defaults
        let basePreferences = mbtiProfile?.audioPreferences ?? AudioPreferences(
            energy: 0.5,
            valence: 0.5,
            tempo: 120,
            complexity: 0.5,
            structure: 0.5,
            variety: 0.5
        )

        // Adjust based on sensor data
        return sensorDataManager.getActivityAdjustedPreferences(basePreferences)
    }

    private func generatePersonalizedRecommendations(
        features: [AudioFeatures],
        mood: Mood,
        preferences: AudioPreferences
    ) async throws -> [Song] {
        // Apply base mood filtering
        let moodFiltered = filterByMood(features, mood: mood)

        // Score by MBTI preferences
        let scoredSongs = scoreByPreferences(moodFiltered, preferences: preferences)

        // Validate and return top recommendations
        guard !scoredSongs.isEmpty else {
            throw AppError.insufficientData
        }

        // Log success
        logger.info("Generated \(scoredSongs.count) recommendations for mood: \(mood.rawValue)")
        AILogger.shared.logInference(
            model: "RecommendationEngine",
            duration: 0,
            success: true
        )

        return Array(scoredSongs.prefix(10))
    }

    private func filterByMood(_ features: [AudioFeatures], mood: Mood) -> [AudioFeatures] {
        let filtered = features.filter { feature in
            switch mood {
            case .energetic:
                feature.energy > 0.7 && feature.tempo > 120
            case .relaxed:
                feature.energy < 0.4 && feature.valence > 0.4
            case .happy:
                feature.valence > 0.7
            case .melancholic:
                feature.valence < 0.4 && feature.tempo < 100
            case .focused:
                feature.complexity > 0.6 && feature.instrumentalness > 0.7
            case .romantic:
                feature.valence > 0.6 && feature.energy < 0.6
            case .angry:
                feature.energy > 0.8 && feature.valence < 0.4
            case .neutral:
                true
            }
        }
        return filtered
    }

    private func scoreByPreferences(_ features: [AudioFeatures], preferences: AudioPreferences) -> [(
        AudioFeatures,
        Float
    )] {
        features.map { feature in
            let scores = MBTIScores(
                energyScore: 1.0 - abs(feature.energy - preferences.energy),
                valenceScore: 1.0 - abs(feature.valence - preferences.valence),
                tempoScore: 1.0 - min(abs(feature.tempo - preferences.tempo) / 60.0, 1.0),
                complexityScore: feature.isComplex == (preferences.complexity > 0.7) ? 1.0 : 0.0,
                structureScore: preferences.structure * (feature.instrumentalness + (1.0 - feature.speechiness)) / 2.0,
                varietyScore: preferences.variety * (feature.spectralFeatures?.irregularity ?? 0.5)
            )

            let weights = getPersonalityBasedWeights()
            let totalScore = (
                scores.energyScore * weights.energy +
                    scores.valenceScore * weights.valence +
                    scores.tempoScore * weights.tempo +
                    scores.complexityScore * weights.complexity +
                    scores.structureScore * weights.structure +
                    scores.varietyScore * weights.variety)

            return (feature, totalScore)
        }
        .sorted { $0.1 > $1.1 }
    }

    private func getPersonalityBasedWeights() -> FeatureWeights {
        guard let profile = mbtiProfile else {
            return .default
        }

        return FeatureWeights(
            // E/I influences importance of energy and tempo
            energy: lerp(0.15, 0.30, profile.extraversion),
            tempo: lerp(0.10, 0.20, profile.extraversion),

            // S/N influences importance of complexity and variety
            complexity: lerp(0.10, 0.20, profile.intuition),
            variety: lerp(0.05, 0.15, profile.intuition),

            // T/F influences importance of valence (emotional content)
            valence: lerp(0.15, 0.25, profile.feeling),

            // J/P influences importance of structure
            structure: lerp(0.10, 0.25, profile.judging)
        )
    }

    // Linear interpolation helper
    private func lerp(_ from: Float, _ to: Float, _ t: Float) -> Float {
        from + (to - from) * t
    }

    private func calculateMatchScore(features: AudioFeatures, preferences: AudioPreferences) -> Float {
        var score: Float = 0

        // Energy match (30% weight)
        score += (1.0 - abs(features.energy - preferences.energy)) * 0.3

        // Valence match (20% weight)
        score += (1.0 - abs(features.valence - preferences.valence)) * 0.2

        // Tempo match (15% weight) - normalized to 0-1 range
        let normalizedTempo = min(1.0, max(0.0, abs(features.tempo - preferences.tempo) / 60.0))
        score += (1.0 - normalizedTempo) * 0.15

        // Complexity match (15% weight)
        let complexity = features.spectralFeatures?.spectralContrast ?? 0.5
        score += (1.0 - abs(complexity - preferences.complexity)) * 0.15

        // Variety contribution (10% weight)
        let variety = features.spectralFeatures?.irregularity ?? 0.5
        score += (1.0 - abs(variety - preferences.variety)) * 0.1

        // Structure match (10% weight)
        let structure = features.spectralFeatures?.harmonicRatio ?? 0.5
        score += (1.0 - abs(structure - preferences.structure)) * 0.1

        return score
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
