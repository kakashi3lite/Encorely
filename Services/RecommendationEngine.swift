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

final class RecommendationEngine: ObservableObject {
    // MARK: - Properties
    
    @Published private(set) var currentRecommendations: [Song] = []
    @Published private(set) var generationProgress: Double = 0
    
    private let moodEngine: MoodEngine
    private let personalityEngine: PersonalityEngine
    private let aiLogger: AILogger
    
    private var subscriptions = Set<AnyCancellable>()
    private let processingQueue = DispatchQueue(label: "com.aimixtapes.recommendations", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(moodEngine: MoodEngine, personalityEngine: PersonalityEngine) {
        self.moodEngine = moodEngine
        self.personalityEngine = personalityEngine
        self.aiLogger = .shared
        
        setupObservers()
    }
    
    // MARK: - Public Interface
    
    /// Generate an AI mixtape based on current mood and personality
    func generateMixtape(length: Int = 12) async throws -> MixTape {
        let startTime = Date()
        generationProgress = 0
        
        // Get current context
        let mood = moodEngine.currentMood
        let personality = personalityEngine.currentPersonality
        
        do {
            // Generate song sequence
            let songs = try await generateSongSequence(
                targetLength: length,
                mood: mood,
                personality: personality
            )
            
            // Create mixtape
            let mixtape = try await createMixtape(
                with: songs,
                mood: mood,
                personality: personality
            )
            
            // Log success
            let duration = Date().timeIntervalSince(startTime)
            aiLogger.logInference(
                model: "MixtapeGeneration",
                duration: duration,
                success: true
            )
            
            generationProgress = 1.0
            return mixtape
            
        } catch {
            aiLogger.logError(model: "MixtapeGeneration", error: .aiServiceUnavailable)
            throw error
        }
    }
    
    /// Get personalized song recommendations
    func getRecommendations(limit: Int = 10) async throws -> [Song] {
        let personality = personalityEngine.currentPersonality
        let preferences = extractUserPreferences()
        
        do {
            let recommendations = try await generateRecommendations(
                count: limit,
                preferences: preferences,
                personality: personality
            )
            
            currentRecommendations = recommendations
            return recommendations
            
        } catch {
            aiLogger.logError(model: "RecommendationGeneration", error: .aiServiceUnavailable)
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Update recommendations when mood changes
        NotificationCenter.default.publisher(for: .moodDidChange)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    try? await self?.refreshRecommendations()
                }
            }
            .store(in: &subscriptions)
        
        // Update recommendations when personality changes
        NotificationCenter.default.publisher(for: .personalityDidChange)
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task {
                    try? await self?.refreshRecommendations()
                }
            }
            .store(in: &subscriptions)
    }
    
    private func generateSongSequence(
        targetLength: Int,
        mood: Mood,
        personality: PersonalityType
    ) async throws -> [Song] {
        var sequence: [Song] = []
        var progress: Double = 0
        
        // Get initial song pool
        let songPool = try await fetchSongPool(mood: mood)
        guard !songPool.isEmpty else {
            throw AppError.insufficientData
        }
        
        // Generate sequence
        while sequence.count < targetLength {
            let nextSong = try await predictNextSong(
                in: songPool,
                currentSequence: sequence,
                mood: mood,
                personality: personality
            )
            
            sequence.append(nextSong)
            
            // Update progress
            progress = Double(sequence.count) / Double(targetLength)
            await MainActor.run {
                generationProgress = progress
            }
        }
        
        return sequence
    }
    
    private func predictNextSong(
        in pool: [Song],
        currentSequence: [Song],
        mood: Mood,
        personality: PersonalityType
    ) async throws -> Song {
        // Calculate transition scores for each candidate song
        let candidates = try await pool.concurrentMap { song in
            let score = calculateTransitionScore(
                from: currentSequence.last,
                to: song,
                mood: mood,
                personality: personality
            )
            return (song, score)
        }
        
        // Sort by score and pick top candidate
        let sortedCandidates = candidates.sorted { $0.1 > $1.1 }
        guard let nextSong = sortedCandidates.first?.0 else {
            throw AppError.inferenceError
        }
        
        return nextSong
    }
    
    private func calculateTransitionScore(
        from currentSong: Song?,
        to nextSong: Song,
        mood: Mood,
        personality: PersonalityType
    ) -> Double {
        var score = 0.0
        
        // Mood congruence (0-1)
        if let currentMood = nextSong.mood {
            score += mood == currentMood ? 1.0 : 0.0
        }
        
        // Energy transition (0-1)
        if let currentSong = currentSong {
            let energyDiff = abs(currentSong.energy - nextSong.energy)
            score += 1.0 - (energyDiff / 1.0)
        }
        
        // Genre compatibility (0-1)
        if let currentSong = currentSong {
            score += currentSong.genre == nextSong.genre ? 1.0 : 0.0
        }
        
        // Personality alignment (0-1)
        switch personality {
        case .explorer:
            // Prefer varied genres and new artists
            score += nextSong.isNewArtist ? 1.0 : 0.0
            
        case .curator:
            // Prefer consistent quality and organization
            score += nextSong.rating >= 4 ? 1.0 : 0.0
            
        case .enthusiast:
            // Prefer deep cuts and related artists
            score += nextSong.popularity < 0.5 ? 1.0 : 0.0
            
        case .social:
            // Prefer popular and shareable songs
            score += nextSong.popularity > 0.7 ? 1.0 : 0.0
            
        case .ambient:
            // Prefer consistent energy levels
            if let currentSong = currentSong {
                let energyDiff = abs(currentSong.energy - nextSong.energy)
                score += energyDiff < 0.2 ? 1.0 : 0.0
            }
            
        case .analyzer:
            // Prefer high audio quality and interesting features
            score += nextSong.audioQuality > 0.8 ? 1.0 : 0.0
            
        default:
            break
        }
        
        return score / 4.0 // Normalize to 0-1
    }
    
    private func createMixtape(
        with songs: [Song],
        mood: Mood,
        personality: PersonalityType
    ) async throws -> MixTape {
        // Generate title
        let title = generateMixtapeTitle(mood: mood, personality: personality)
        
        // Create mixtape
        let mixtape = MixTape(context: PersistenceController.shared.container.viewContext)
        mixtape.title = title
        mixtape.createdDate = Date()
        mixtape.mood = mood.rawValue
        mixtape.isAIGenerated = true
        
        // Add songs
        for (index, song) in songs.enumerated() {
            let songItem = SongItem(context: PersistenceController.shared.container.viewContext)
            songItem.song = song
            songItem.order = Int16(index)
            mixtape.addToSongs(songItem)
        }
        
        // Save context
        try PersistenceController.shared.container.viewContext.save()
        
        return mixtape
    }
    
    private func generateMixtapeTitle(mood: Mood, personality: PersonalityType) -> String {
        // Simple title generation (could be enhanced with ML)
        let moodAdjectives: [Mood: [String]] = [
            .happy: ["Uplifting", "Joyful", "Sunny"],
            .energetic: ["Energizing", "Powerful", "Dynamic"],
            .relaxed: ["Peaceful", "Calming", "Serene"],
            .melancholic: ["Reflective", "Moody", "Deep"],
            .focused: ["Focused", "Clear", "Sharp"],
            .romantic: ["Romantic", "Intimate", "Tender"]
        ]
        
        let personalityNouns: [PersonalityType: [String]] = [
            .explorer: ["Journey", "Discovery", "Adventure"],
            .curator: ["Collection", "Selection", "Curation"],
            .enthusiast: ["Experience", "Passion", "Essence"],
            .social: ["Connection", "Sharing", "Gathering"],
            .ambient: ["Flow", "Atmosphere", "Space"],
            .analyzer: ["Analysis", "Elements", "Composition"]
        ]
        
        let adjective = moodAdjectives[mood]?.randomElement() ?? "Musical"
        let noun = personalityNouns[personality]?.randomElement() ?? "Mixtape"
        
        return "\(adjective) \(noun)"
    }
    
    private func extractUserPreferences() -> [String: Any] {
        // Analyze listening history and extract preferences
        [
            "genres": ["rock": 0.4, "jazz": 0.3, "classical": 0.3],
            "tempo": ["slow": 0.3, "medium": 0.4, "fast": 0.3],
            "energy": 0.6,
            "valence": 0.7
        ]
    }
    
    private func generateRecommendations(
        count: Int,
        preferences: [String: Any],
        personality: PersonalityType
    ) async throws -> [Song] {
        // Implementation would use ML model to generate recommendations
        // This is a placeholder
        []
    }
    
    private func fetchSongPool(mood: Mood) async throws -> [Song] {
        // Implementation would fetch songs from database
        // This is a placeholder
        []
    }
    
    private func refreshRecommendations() async throws {
        try await getRecommendations()
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
