//
//  AIIntegrationService.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import CoreData

/// Central service that coordinates all AI features of the Mixtapes app
class AIIntegrationService: ObservableObject {
    // Child services
    let moodEngine: MoodEngine
    let personalityEngine: PersonalityEngine
    let recommendationEngine: RecommendationEngine
    
    // Analytics tracking
    private var interactionHistory: [InteractionEvent] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext) {
        // Initialize child services
        self.moodEngine = MoodEngine()
        self.personalityEngine = PersonalityEngine()
        self.recommendationEngine = RecommendationEngine(context: context)
        
        // Connect services
        setupInterServiceCommunication()
        
        // Load initial user data
        loadUserPreferences()
        
        // Start periodic mood updates based on time of day
        startPeriodicUpdates()
    }
    
    private func setupInterServiceCommunication() {
        // Wire up the services to communicate with each other
        moodEngine.$currentMood
            .sink { [weak self] mood in
                self?.recommendationEngine.updateMood(mood)
            }
            .store(in: &cancellables)
        
        personalityEngine.$currentPersonality
            .sink { [weak self] personality in
                self?.recommendationEngine.updatePersonality(personality)
            }
            .store(in: &cancellables)
    }
    
    private func startPeriodicUpdates() {
        // Update mood based on time of day every hour
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.moodEngine.updateMoodBasedOnTimeOfDay()
            }
            .store(in: &cancellables)
    }
    
    private func loadUserPreferences() {
        // Load from UserDefaults
        if let moodString = UserDefaults.standard.string(forKey: "userMood"),
           let mood = Mood(rawValue: moodString) {
            moodEngine.currentMood = mood
        }
        
        if let personalityString = UserDefaults.standard.string(forKey: "userPersonality"),
           let personality = PersonalityType(rawValue: personalityString) {
            personalityEngine.currentPersonality = personality
        }
    }
    
    func saveUserPreferences() {
        // Save to UserDefaults
        UserDefaults.standard.set(moodEngine.currentMood.rawValue, forKey: "userMood")
        UserDefaults.standard.set(personalityEngine.currentPersonality.rawValue, forKey: "userPersonality")
    }
    
    // Track user interactions for AI learning
    func trackInteraction(type: String, mixtape: MixTape? = nil) {
        let event = InteractionEvent(
            timestamp: Date(),
            type: type,
            mixtapeId: mixtape?.objectID.uriRepresentation().absoluteString,
            mood: moodEngine.currentMood.rawValue,
            personality: personalityEngine.currentPersonality.rawValue
        )
        
        interactionHistory.append(event)
        processInteraction(event)
        
        // Periodically save interaction data
        if interactionHistory.count % 10 == 0 {
            saveInteractionHistory()
        }
    }
    
    private func processInteraction(_ event: InteractionEvent) {
        // Send the event to each engine for learning/adaptation
        personalityEngine.processInteraction(event)
        moodEngine.processInteraction(event)
        recommendationEngine.processInteraction(event)
    }
    
    private func saveInteractionHistory() {
        // Save interaction history to persistent storage
        // This would typically be done with CoreData or a similar mechanism
        // For now, we'll just keep it in memory
    }
    
    // Get personalized mixtape recommendations
    func getPersonalizedRecommendations() -> [MixTape] {
        return recommendationEngine.getRecommendations()
    }
    
    // Detect mood from audio being played
    func detectMoodFromCurrentAudio(player: AVQueuePlayer) {
        // In a real implementation, this would analyze audio features
        // For demonstration purposes, we'll simulate this with random values
        
        if let currentItem = player.currentItem {
            // Simulate extracting audio features
            let tempo = Float.random(in: 80...160)  // BPM
            let energy = Float.random(in: 0...1)    // 0-1 scale
            let valence = Float.random(in: 0...1)   // Musical positiveness
            
            // Update mood based on these features
            moodEngine.detectMoodFromAudioFeatures(tempo: tempo, energy: energy, valence: valence)
        }
    }
    
    // Get a greeting message based on current mood and personality
    func getPersonalizedGreeting() -> String {
        let timeGreeting: String
        let hour = Calendar.current.component(.hour, from: Date())
        
        if hour >= 5 && hour < 12 {
            timeGreeting = "Good morning"
        } else if hour >= 12 && hour < 17 {
            timeGreeting = "Good afternoon"
        } else if hour >= 17 && hour < 22 {
            timeGreeting = "Good evening"
        } else {
            timeGreeting = "Hello"
        }
        
        // Add mood-specific component
        let moodComponent: String
        switch moodEngine.currentMood {
        case .energetic:
            moodComponent = "Ready to energize your day with some music?"
        case .relaxed:
            moodComponent = "Time to unwind with some relaxing tunes?"
        case .happy:
            moodComponent = "Let's keep that positive vibe going!"
        case .melancholic:
            moodComponent = "How about some music to match your reflective mood?"
        case .focused:
            moodComponent = "Looking for something to help you concentrate?"
        case .romantic:
            moodComponent = "In the mood for something with feeling?"
        case .angry:
            moodComponent = "Need to channel some intensity today?"
        case .neutral:
            moodComponent = "What would you like to listen to today?"
        }
        
        // Personality affects greeting style
        switch personalityEngine.currentPersonality {
        case .explorer:
            return "\(timeGreeting)! \(moodComponent) Try something new today!"
        case .curator:
            return "\(timeGreeting). \(moodComponent) Your collections are looking great."
        case .enthusiast:
            return "\(timeGreeting)! \(moodComponent) Dive deep into your favorite tunes."
        case .social:
            return "\(timeGreeting)! \(moodComponent) Share some great music with friends today."
        case .ambient:
            return "\(timeGreeting). \(moodComponent) Perfect soundtrack for your day."
        case .analyzer:
            return "\(timeGreeting). \(moodComponent) Analyze your collection with new insights."
        }
    }
    
    // Get insights about the user's listening habits
    func getUserInsights() -> String {
        // In a real app, this would analyze actual listening data
        // For now, we'll generate a simple insight based on personality and mood
        
        let personalityInsight: String
        switch personalityEngine.currentPersonality {
        case .explorer:
            personalityInsight = "You enjoy discovering new music regularly."
        case .curator:
            personalityInsight = "You take pride in organizing your music collections."
        case .enthusiast:
            personalityInsight = "You tend to deeply explore your favorite artists."
        case .social:
            personalityInsight = "You often share music with others."
        case .ambient:
            personalityInsight = "You frequently use music as background accompaniment."
        case .analyzer:
            personalityInsight = "You appreciate the technical aspects of your music."
        }
        
        let moodInsight: String
        switch moodEngine.currentMood {
        case .energetic:
            moodInsight = "Today's selections can help maintain your energy."
        case .relaxed:
            moodInsight = "Your current playlist choices promote relaxation."
        case .happy:
            moodInsight = "Your music selections reflect your positive mood."
        case .melancholic:
            moodInsight = "Your playlist supports thoughtful reflection."
        case .focused:
            moodInsight = "The current mixtapes help maintain concentration."
        case .romantic:
            moodInsight = "Your selections have emotional depth today."
        case .angry:
            moodInsight = "Your music choices help channel intense emotions."
        case .neutral:
            moodInsight = "Your current selections are versatile for any activity."
        }
        
        return "\(personalityInsight) \(moodInsight)"
    }
}

// Model for tracking user interactions
struct InteractionEvent {
    let timestamp: Date
    let type: String
    let mixtapeId: String?
    let mood: String
    let personality: String
    
    // Additional contextual data could be added here
}
