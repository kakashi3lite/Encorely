//
//  RecommendationEngine.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import CoreData
import Combine

/// Engine responsible for generating personalized recommendations based on user mood and personality
class RecommendationEngine: ObservableObject {
    // CoreData context for accessing MixTape data
    private let context: NSManagedObjectContext
    
    // Current state from other services
    private var currentMood: Mood = .neutral
    private var currentPersonality: PersonalityType = .curator
    
    // Recommendation patterns
    private var userPreferences: [String: Float] = [:]
    private var recommendationHistory: [String: Date] = [:]
    
    // Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext) {
        self.context = context
        
        // Load saved preferences
        loadUserPreferences()
        
        // Set up timer to refresh recommendations periodically
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.generateRecommendations()
            }
            .store(in: &cancellables)
    }
    
    /// Update the current mood from MoodEngine
    func updateMood(_ mood: Mood) {
        self.currentMood = mood
    }
    
    /// Update the current personality from PersonalityEngine
    func updatePersonality(_ personality: PersonalityType) {
        self.currentPersonality = personality
    }
    
    /// Process user interaction to improve recommendations
    func processInteraction(_ event: InteractionEvent) {
        // Extract information from the event to update preferences
        if let mixtapeId = event.mixtapeId {
            if event.type.contains("play") || event.type.contains("select") {
                // Increase preference score for this mixtape
                incrementPreference(for: mixtapeId, by: 0.1)
            } else if event.type.contains("skip") {
                // Decrease preference score for this mixtape
                incrementPreference(for: mixtapeId, by: -0.05)
            } else if event.type.contains("repeat") {
                // Strongly increase preference score for this mixtape
                incrementPreference(for: mixtapeId, by: 0.2)
            } else if event.type.contains("share") {
                // Moderately increase preference score for this mixtape
                incrementPreference(for: mixtapeId, by: 0.15)
            } else if event.type.contains("delete") {
                // Strongly decrease preference score for this mixtape
                incrementPreference(for: mixtapeId, by: -0.3)
            }
            
            // Update recommendation history
            recommendationHistory[mixtapeId] = Date()
        }
        
        // Analyze event keywords to adjust genre/style preferences
        updatePreferencesFromKeywords(in: event.type)
    }
    
    /// Update user preferences based on keywords in an interaction
    private func updatePreferencesFromKeywords(in interactionType: String) {
        // Examples of how keywords might map to preferences
        let keywordMapping: [String: String] = [
            "rock": "genre_rock",
            "jazz": "genre_jazz",
            "pop": "genre_pop",
            "classical": "genre_classical",
            "electronic": "genre_electronic",
            "ambient": "genre_ambient",
            "instrumental": "style_instrumental",
            "vocal": "style_vocal",
            "chill": "style_relaxed",
            "upbeat": "style_energetic",
            "workout": "context_workout",
            "study": "context_focus",
            "party": "context_social",
            "sleep": "context_sleep"
        ]
        
        // Check for keywords in the interaction type
        for (keyword, preference) in keywordMapping {
            if interactionType.lowercased().contains(keyword) {
                incrementPreference(for: preference, by: 0.1)
            }
        }
    }
    
    /// Increment the preference score for a specific ID
    private func incrementPreference(for id: String, by amount: Float) {
        let currentValue = userPreferences[id] ?? 0.0
        userPreferences[id] = min(1.0, max(-1.0, currentValue + amount))
        
        // Save updated preferences
        saveUserPreferences()
    }
    
    /// Generate a list of recommended mixtapes
    func getRecommendations() -> [MixTape] {
        // In a real app, this would use a more sophisticated algorithm
        // For now, we'll implement a simple scoring mechanism
        
        // Try to fetch all mixtapes
        let fetchRequest: NSFetchRequest<MixTape> = MixTape.fetchRequest()
        
        do {
            let allMixTapes = try context.fetch(fetchRequest)
            
            // Score each mixtape based on various factors
            let scoredMixTapes = allMixTapes.map { mixtape -> (mixtape: MixTape, score: Float) in
                let mixtapeId = mixtape.objectID.uriRepresentation().absoluteString
                
                // Base score from explicit user preferences
                let preferenceScore = userPreferences[mixtapeId] ?? 0.0
                
                // Mood-based score component
                let moodScore = calculateMoodCompatibility(for: mixtape)
                
                // Personality-based score component
                let personalityScore = calculatePersonalityCompatibility(for: mixtape)
                
                // Recency factor (avoid recommending the same mixtapes too often)
                let recencyScore = calculateRecencyScore(for: mixtapeId)
                
                // Combine all factors (weights could be adjusted)
                let totalScore = (preferenceScore * 0.4) + (moodScore * 0.3) + (personalityScore * 0.2) + (recencyScore * 0.1)
                
                return (mixtape: mixtape, score: totalScore)
            }
            
            // Sort by score and return mixtapes
            return scoredMixTapes
                .sorted { $0.score > $1.score }
                .map { $0.mixtape }
            
        } catch {
            print("Error fetching mixtapes for recommendations: \(error)")
            return []
        }
    }
    
    /// Calculate how well a mixtape matches the current mood
    private func calculateMoodCompatibility(for mixtape: MixTape) -> Float {
        // In a real implementation, this would analyze the mixtape's content
        // For now, we'll use a simplified approach
        
        let mixtapeId = mixtape.objectID.uriRepresentation().absoluteString
        var moodScore: Float = 0.0
        
        // Check if mixtape name contains mood keywords
        let mixtapeName = mixtape.wrappedTitle.lowercased()
        
        // Look for current mood keywords in the mixtape name
        for keyword in currentMood.keywords {
            if mixtapeName.contains(keyword.lowercased()) {
                moodScore += 0.2
                break
            }
        }
        
        // Check recent interactions with this mixtape during current mood
        if let lastInteraction = recommendationHistory[mixtapeId],
           Calendar.current.isDateInToday(lastInteraction) {
            moodScore += 0.1
        }
        
        return min(1.0, moodScore)
    }
    
    /// Calculate how well a mixtape matches the current personality type
    private func calculatePersonalityCompatibility(for mixtape: MixTape) -> Float {
        // Simple check based on mixtape characteristics that might match personality
        var personalityScore: Float = 0.0
        
        switch currentPersonality {
        case .explorer:
            // Explorers might prefer varied content they haven't played much
            if mixtape.numberOfSongs > 10 {
                personalityScore += 0.2
            }
            
            // Prefer mixtapes they haven't interacted with recently
            let mixtapeId = mixtape.objectID.uriRepresentation().absoluteString
            if recommendationHistory[mixtapeId] == nil {
                personalityScore += 0.3
            }
            
        case .curator:
            // Curators might prefer carefully organized, complete collections
            if mixtape.numberOfSongs > 5 && mixtape.numberOfSongs < 20 {
                personalityScore += 0.3
            }
            
        case .enthusiast:
            // Enthusiasts might prefer deep, focused collections
            if mixtape.numberOfSongs > 15 {
                personalityScore += 0.3
            }
            
        case .social:
            // Social users might prefer content with sharing potential
            if mixtape.wrappedTitle.lowercased().contains("party") ||
               mixtape.wrappedTitle.lowercased().contains("hits") {
                personalityScore += 0.3
            }
            
        case .ambient:
            // Ambient users might prefer background, atmospheric content
            if mixtape.wrappedTitle.lowercased().contains("chill") ||
               mixtape.wrappedTitle.lowercased().contains("ambient") ||
               mixtape.wrappedTitle.lowercased().contains("relax") {
                personalityScore += 0.4
            }
            
        case .analyzer:
            // Analyzers might prefer technical, detailed content
            if mixtape.numberOfSongs > 0 {
                personalityScore += Float(mixtape.numberOfSongs) / 50.0 // Score based on complexity
            }
        }
        
        return min(1.0, personalityScore)
    }
    
    /// Calculate a score based on how recently the mixtape was recommended
    private func calculateRecencyScore(for mixtapeId: String) -> Float {
        // If never recommended before, give it a high score
        guard let lastRecommended = recommendationHistory[mixtapeId] else {
            return 1.0
        }
        
        // Calculate how many days since last recommended
        let daysSinceLastRecommended = Calendar.current.dateComponents([.day], from: lastRecommended, to: Date()).day ?? 0
        
        // Score increases as more time passes
        return min(1.0, Float(daysSinceLastRecommended) / 7.0)
    }
    
    /// Generate a list of mood-appropriate new mixtape name suggestions
    func getSuggestedMixtapeTitles() -> [String] {
        var suggestions: [String] = []
        
        // Add some based on current mood
        switch currentMood {
        case .energetic:
            suggestions.append(contentsOf: ["Power Hour", "Workout Beats", "Energy Boost"])
        case .relaxed:
            suggestions.append(contentsOf: ["Chill Session", "Relaxation Mix", "Evening Wind Down"])
        case .happy:
            suggestions.append(contentsOf: ["Happy Days", "Feel Good Mix", "Sunshine Vibes"])
        case .melancholic:
            suggestions.append(contentsOf: ["Reflection", "Rainy Day", "Melancholy Moments"])
        case .focused:
            suggestions.append(contentsOf: ["Deep Focus", "Concentration Zone", "Productivity Mix"])
        case .romantic:
            suggestions.append(contentsOf: ["Love Songs", "Date Night", "Romantic Evening"])
        case .angry:
            suggestions.append(contentsOf: ["Release", "Intensity", "Catharsis"])
        case .neutral:
            suggestions.append(contentsOf: ["Everyday Mix", "Daily Soundtrack", "My Playlist"])
        }
        
        // Add some based on personality type
        switch currentPersonality {
        case .explorer:
            suggestions.append(contentsOf: ["Discovery Playlist", "New Horizons", "Uncharted Territory"])
        case .curator:
            suggestions.append(contentsOf: ["Carefully Curated", "The Collection", "Essential Selection"])
        case .enthusiast:
            suggestions.append(contentsOf: ["Deep Dive", "The Complete Experience", "Expert Selection"])
        case .social:
            suggestions.append(contentsOf: ["Party Starter", "Friend Group Mix", "Share-worthy Tracks"])
        case .ambient:
            suggestions.append(contentsOf: ["Background Soundtrack", "Atmospheric Sounds", "Passive Listening"])
        case .analyzer:
            suggestions.append(contentsOf: ["Technical Excellence", "Audio Showcase", "Sonic Details"])
        }
        
        // Some generic suggestions
        let genericSuggestions = [
            "My Mixtape",
            "New Collection",
            "Favorite Tracks",
            "Personal Mix",
            "Playlist 1"
        ]
        
        suggestions.append(contentsOf: genericSuggestions)
        
        // Shuffle and limit the results
        return Array(Set(suggestions)).shuffled().prefix(10).map { $0 }
    }
    
    /// Generate new recommendations
    private func generateRecommendations() {
        // This would typically use ML or similar techniques to generate personalized recommendations
        // For now, we'll rely on the scoring in getRecommendations()
    }
    
    /// Load user preferences from persistent storage
    private func loadUserPreferences() {
        if let savedPreferences = UserDefaults.standard.dictionary(forKey: "userMusicPreferences") as? [String: Float] {
            self.userPreferences = savedPreferences
        }
    }
    
    /// Save user preferences to persistent storage
    private func saveUserPreferences() {
        UserDefaults.standard.set(userPreferences, forKey: "userMusicPreferences")
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
