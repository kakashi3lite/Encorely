//
//  RecommendationEngine.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import CoreML
import Combine
import os.log

class RecommendationEngine: ObservableObject {
    // MARK: - Properties
    
    @Published private(set) var currentRecommendations: [Song] = []
    @Published private(set) var isGenerating = false
    
    // State management
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
    
    init() {
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
        // Apply personality-based filtering
        let filteredFeatures = filterByPersonality(features, personality: personality)
        
        // Apply mood-based scoring
        let scoredFeatures = scoreByMood(filteredFeatures, targetMood: mood)
        
        // Sort by score and convert back to songs
        let recommendations = scoredFeatures
            .sorted { $0.score > $1.score }
            .prefix(10)
            .compactMap { $0.song }
        
        return Array(recommendations)
    }
    
    private func filterByPersonality(
        _ features: [AudioFeatures],
        personality: PersonalityType
    ) -> [(song: Song, features: AudioFeatures)] {
        switch personality {
        case .explorer:
            // Prefer diverse recommendations
            return features.shuffled().map { ($0.song, $0) }
        case .enthusiast:
            // Prefer high-energy content
            return features
                .filter { $0.energy > 0.6 }
                .map { ($0.song, $0) }
        case .curator:
            // Prefer consistent, themed content
            return features
                .filter { $0.matches(currentMood) }
                .map { ($0.song, $0) }
        }
    }
    
    private func scoreByMood(
        _ features: [(song: Song, features: AudioFeatures)],
        targetMood: Mood
    ) -> [(song: Song, score: Float)] {
        features.map { songFeatures in
            let score = calculateMoodScore(
                features: songFeatures.features,
                targetMood: targetMood
            )
            return (song: songFeatures.song, score: score)
        }
    }
    
    private func calculateMoodScore(features: AudioFeatures, targetMood: Mood) -> Float {
        let moodIndicators = features.moodIndicators()
        
        switch targetMood {
        case .energetic:
            return (moodIndicators.energy * 0.4 +
                   moodIndicators.density * 0.3 +
                   moodIndicators.brightness * 0.3)
        case .relaxed:
            return ((1 - moodIndicators.energy) * 0.4 +
                   (1 - moodIndicators.density) * 0.3 +
                   moodIndicators.brightness * 0.3)
        case .happy:
            return (moodIndicators.brightness * 0.4 +
                   moodIndicators.energy * 0.3 +
                   (1 - moodIndicators.complexity) * 0.3)
        case .melancholic:
            return ((1 - moodIndicators.brightness) * 0.4 +
                   moodIndicators.complexity * 0.3 +
                   (1 - moodIndicators.energy) * 0.3)
        default:
            return 0.5 // Neutral score for other moods
        }
    }
    
    private func generateCacheKey(mood: Mood, songs: [Song]) -> String {
        let songIds = songs.map { $0.id.uuidString }.joined(separator: "-")
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
        _ transform: @escaping (Element) async throws -> T
    ) async throws -> [T] {
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
            return songsArray.sorted { _, _ in
                // This would actually sort by tempo/energy in a real implementation
                Bool.random()
            }
            
        case .relaxed:
            // For relaxed mood, start mellow and get progressively more relaxed
            return songsArray.sorted { _, _ in
                // This would actually sort by tempo/energy in a real implementation
                Bool.random()
            }
            
        default:
            // Default to original order for other moods
            return songsArray
        }
    }
    
    /// Analyzes the audio characteristics of the mixtape to determine mood compatibility
    func getMoodCompatibility() -> [Mood: Float] {
        // In a real implementation, this would analyze audio features
        // For now, return random values for demonstration
        
        var compatibility: [Mood: Float] = [:]
        
        for mood in Mood.allCases {
            compatibility[mood] = Float.random(in: 0...1)
        }
        
        return compatibility
    }
}
