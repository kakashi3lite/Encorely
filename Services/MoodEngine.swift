//
//  MoodEngine.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import SwiftUI
import CoreML
import Vision

/// Enum representing different mood states the app can detect and use
enum Mood: String, CaseIterable {
    case energetic = "Energetic"
    case relaxed = "Relaxed"
    case happy = "Happy"
    case melancholic = "Melancholic"
    case focused = "Focused"
    case romantic = "Romantic"
    case angry = "Angry"
    case neutral = "Neutral"
    
    /// Returns a color associated with each mood
    var color: Color {
        switch self {
        case .energetic: return Color.orange
        case .relaxed: return Color.blue
        case .happy: return Color.yellow
        case .melancholic: return Color.purple
        case .focused: return Color.green
        case .romantic: return Color.pink
        case .angry: return Color.red
        case .neutral: return Color.gray
        }
    }
    
    /// Returns a system icon name for each mood
    var systemIcon: String {
        switch self {
        case .energetic: return "bolt.fill"
        case .relaxed: return "leaf.fill"
        case .happy: return "sun.max.fill"
        case .melancholic: return "cloud.rain.fill"
        case .focused: return "target"
        case .romantic: return "heart.fill"
        case .angry: return "flame.fill"
        case .neutral: return "circle.fill"
        }
    }
    
    /// Returns keywords associated with each mood
    var keywords: [String] {
        switch self {
        case .energetic: return ["energy", "power", "workout", "upbeat", "dance", "fast", "gym"]
        case .relaxed: return ["calm", "chill", "peaceful", "gentle", "slow", "ambient", "sleep"]
        case .happy: return ["joy", "uplifting", "cheerful", "bright", "optimistic", "fun"]
        case .melancholic: return ["sad", "nostalgic", "emotional", "reflective", "sorrow", "longing"]
        case .focused: return ["concentration", "study", "work", "instrumental", "productivity"]
        case .romantic: return ["love", "date", "dreamy", "intimate", "passion", "evening"]
        case .angry: return ["intense", "heavy", "aggressive", "powerful", "strong", "frustrated"]
        case .neutral: return ["balanced", "mixed", "moderate", "versatile", "everyday"]
        }
    }
}

/// Struct representing a suggested action based on mood
struct MoodAction {
    let title: String
    let action: String
    let mood: Mood
    let confidence: Float
}

/// Engine responsible for detecting, analyzing and providing recommendations based on mood
class MoodEngine: ObservableObject {
    @Published var currentMood: Mood = .neutral
    @Published var moodConfidence: Float = 0.5
    
    // Mood analysis parameters
    private var moodIntensities: [Mood: Float] = [:]
    private var moodDetectionHistory: [(mood: Mood, timestamp: Date, confidence: Float)] = []
    
    // ML model for mood detection
    // In a real app, this would be implemented with actual CoreML model
    private var moodDetectionModel: VNCoreMLModel?
    
    init() {
        // Initialize mood intensities
        for mood in Mood.allCases {
            moodIntensities[mood] = 0.0
        }
        
        // Default mood is neutral with medium confidence
        moodIntensities[.neutral] = 0.5
        
        // Try to load ML model for mood detection (simplified here)
        setupMoodDetectionModel()
    }
    
    private func setupMoodDetectionModel() {
        // In a real app, this would load an actual CoreML model
        // For demonstration purposes, we're just simulating this capability
        
        // Simulated model loading success
        let success = true
        
        if success {
            print("Mood detection model loaded successfully")
        } else {
            print("Failed to load mood detection model")
        }
    }
    
    /// Process user interaction to learn and adapt mood detection
    func processInteraction(_ event: InteractionEvent) {
        // Analyze the interaction to update mood estimations
        if event.type.contains("play") {
            // User started playing music - this can indicate mood confirmation
            increaseConfidenceInCurrentMood()
        } else if event.type.contains("skip") {
            // User skipped a song - might indicate mood mismatch
            decreaseConfidenceInCurrentMood()
        } else if event.type.contains("mood_selected_") {
            // Direct mood selection by user
            if let moodString = event.type.split(separator: "_").last,
               let mood = Mood(rawValue: String(moodString)) {
                setMood(mood, confidence: 0.9)
            }
        }
    }
    
    /// Detect mood from facial expressions using Vision framework
    func detectMoodFromFacialExpression(image: UIImage) {
        // This would use Vision and CoreML in a real implementation
        // Here we're just simulating the functionality
        
        // Simulate mood detection with random result (for demonstration)
        let detectedMoods: [(mood: Mood, confidence: Float)] = [
            (.happy, 0.7),
            (.neutral, 0.2),
            (.relaxed, 0.1)
        ]
        
        // Update mood based on strongest detection
        if let strongestMood = detectedMoods.max(by: { $0.confidence < $1.confidence }) {
            updateMoodWithDetection(mood: strongestMood.mood, confidence: strongestMood.confidence)
        }
    }
    
    /// Detect mood from audio features
    func detectMoodFromAudioFeatures(tempo: Float, energy: Float, valence: Float) {
        // Map audio features to mood
        // - Tempo: speed of the track (BPM)
        // - Energy: intensity and activity of the track
        // - Valence: musical positiveness of the track
        
        var detectedMood: Mood = .neutral
        var confidence: Float = 0.5
        
        // Simple mapping algorithm (would be more sophisticated in a real app)
        if tempo > 120 && energy > 0.8 {
            if valence > 0.7 {
                detectedMood = .energetic
                confidence = min(1.0, (tempo - 100) / 100)
            } else if valence < 0.3 {
                detectedMood = .angry
                confidence = min(1.0, energy * 0.9)
            }
        } else if tempo < 100 && energy < 0.4 {
            if valence > 0.6 {
                detectedMood = .relaxed
                confidence = min(1.0, (1.0 - energy) * 0.8)
            } else if valence < 0.4 {
                detectedMood = .melancholic
                confidence = min(1.0, (1.0 - valence) * 0.8)
            }
        } else if valence > 0.7 {
            detectedMood = .happy
            confidence = min(1.0, valence * 0.9)
        } else if energy > 0.5 && valence > 0.4 && valence < 0.6 {
            detectedMood = .focused
            confidence = min(1.0, energy * 0.7)
        }
        
        updateMoodWithDetection(mood: detectedMood, confidence: confidence)
    }
    
    /// Update mood based on time of day
    func updateMoodBasedOnTimeOfDay() {
        let hour = Calendar.current.component(.hour, from: Date())
        var timeBasedMood: Mood = .neutral
        var confidence: Float = 0.3 // Time is a weaker signal than direct user input
        
        switch hour {
        case 5..<9: // Early morning
            timeBasedMood = .energetic
            confidence = 0.4
        case 9..<12: // Morning
            timeBasedMood = .focused
            confidence = 0.5
        case 12..<14: // Lunch
            timeBasedMood = .happy
            confidence = 0.3
        case 14..<17: // Afternoon
            timeBasedMood = .focused
            confidence = 0.5
        case 17..<20: // Evening
            timeBasedMood = .relaxed
            confidence = 0.4
        case 20..<23: // Night
            timeBasedMood = .romantic
            confidence = 0.4
        default: // Late night
            timeBasedMood = .melancholic
            confidence = 0.3
        }
        
        // Only update if confidence is higher than current or if current is low
        if confidence > moodConfidence || moodConfidence < 0.2 {
            updateMoodWithDetection(mood: timeBasedMood, confidence: confidence)
        }
    }
    
    /// Sets a specific mood with given confidence
    func setMood(_ mood: Mood, confidence: Float) {
        currentMood = mood
        moodConfidence = confidence
        moodIntensities[mood] = confidence
        
        // Record in history
        moodDetectionHistory.append((mood: mood, timestamp: Date(), confidence: confidence))
        
        // Limit history size
        if moodDetectionHistory.count > 100 {
            moodDetectionHistory.removeFirst()
        }
    }
    
    /// Updates the mood based on a new detection
    private func updateMoodWithDetection(mood: Mood, confidence: Float) {
        // Add to history
        moodDetectionHistory.append((mood: mood, timestamp: Date(), confidence: confidence))
        
        // Update mood intensities with decay function for older detections
        updateMoodIntensities()
        
        // Set the strongest mood as current
        if let strongestMood = moodIntensities.max(by: { $0.value < $1.value }) {
            currentMood = strongestMood.key
            moodConfidence = strongestMood.value
        }
    }
    
    /// Updates mood intensities based on detection history
    private func updateMoodIntensities() {
        // Reset intensities
        for mood in Mood.allCases {
            moodIntensities[mood] = 0.0
        }
        
        // Apply decay function - more recent detections have more weight
        let now = Date()
        for detection in moodDetectionHistory {
            let timeInterval = now.timeIntervalSince(detection.timestamp)
            let decayFactor = max(0.0, 1.0 - Float(timeInterval / 3600)) // 1-hour decay
            
            if let currentIntensity = moodIntensities[detection.mood] {
                moodIntensities[detection.mood] = max(currentIntensity, detection.confidence * decayFactor)
            }
        }
    }
    
    /// Increase confidence in the current mood
    private func increaseConfidenceInCurrentMood() {
        moodConfidence = min(1.0, moodConfidence + 0.1)
        moodIntensities[currentMood] = moodConfidence
    }
    
    /// Decrease confidence in the current mood
    private func decreaseConfidenceInCurrentMood() {
        moodConfidence = max(0.1, moodConfidence - 0.15)
        moodIntensities[currentMood] = moodConfidence
        
        // If confidence gets too low, fallback to neutral
        if moodConfidence < 0.2 {
            currentMood = .neutral
            moodConfidence = 0.5
            moodIntensities[.neutral] = 0.5
        }
    }
    
    /// Gets mood-based recommendations from a list of mixtapes
    func getMoodBasedRecommendations() -> [MixTape] {
        // In a real implementation, this would search through available mixtapes
        // and score them based on their compatibility with the current mood
        
        // For now, we'll return an empty array as a placeholder
        return []
    }
    
    /// Gets suggested actions based on the current mood
    func getMoodBasedActions() -> [MoodAction] {
        var actions: [MoodAction] = []
        
        switch currentMood {
        case .energetic:
            actions = [
                MoodAction(title: "Workout Mix", action: "create_mixtape_workout", mood: .energetic, confidence: moodConfidence),
                MoodAction(title: "Dance Party", action: "start_dance_playlist", mood: .energetic, confidence: moodConfidence),
                MoodAction(title: "Morning Energizer", action: "play_morning_boost", mood: .energetic, confidence: moodConfidence)
            ]
        case .relaxed:
            actions = [
                MoodAction(title: "Peaceful Evening", action: "create_mixtape_relax", mood: .relaxed, confidence: moodConfidence),
                MoodAction(title: "Sleep Sounds", action: "play_sleep_playlist", mood: .relaxed, confidence: moodConfidence),
                MoodAction(title: "Ambient Focus", action: "create_mixtape_ambient", mood: .relaxed, confidence: moodConfidence)
            ]
        case .happy:
            actions = [
                MoodAction(title: "Uplifting Mix", action: "create_mixtape_happy", mood: .happy, confidence: moodConfidence),
                MoodAction(title: "Party Starter", action: "play_party_playlist", mood: .happy, confidence: moodConfidence),
                MoodAction(title: "Sunny Day", action: "create_mixtape_sunshine", mood: .happy, confidence: moodConfidence)
            ]
        case .melancholic:
            actions = [
                MoodAction(title: "Reflective Journey", action: "create_mixtape_reflection", mood: .melancholic, confidence: moodConfidence),
                MoodAction(title: "Rainy Day", action: "play_rainy_playlist", mood: .melancholic, confidence: moodConfidence),
                MoodAction(title: "Late Night Thoughts", action: "create_mixtape_night", mood: .melancholic, confidence: moodConfidence)
            ]
        case .focused:
            actions = [
                MoodAction(title: "Deep Work", action: "create_mixtape_focus", mood: .focused, confidence: moodConfidence),
                MoodAction(title: "Study Session", action: "play_study_playlist", mood: .focused, confidence: moodConfidence),
                MoodAction(title: "Productivity Boost", action: "create_mixtape_productivity", mood: .focused, confidence: moodConfidence)
            ]
        case .romantic:
            actions = [
                MoodAction(title: "Date Night", action: "create_mixtape_date", mood: .romantic, confidence: moodConfidence),
                MoodAction(title: "Love Songs", action: "play_love_playlist", mood: .romantic, confidence: moodConfidence),
                MoodAction(title: "Dreamy Evening", action: "create_mixtape_dreamy", mood: .romantic, confidence: moodConfidence)
            ]
        case .angry:
            actions = [
                MoodAction(title: "Release Tension", action: "create_mixtape_release", mood: .angry, confidence: moodConfidence),
                MoodAction(title: "Intense Workout", action: "play_intense_playlist", mood: .angry, confidence: moodConfidence),
                MoodAction(title: "Power Mix", action: "create_mixtape_power", mood: .angry, confidence: moodConfidence)
            ]
        case .neutral:
            actions = [
                MoodAction(title: "Discover Something New", action: "create_mixtape_discover", mood: .neutral, confidence: moodConfidence),
                MoodAction(title: "Balanced Mix", action: "play_balanced_playlist", mood: .neutral, confidence: moodConfidence),
                MoodAction(title: "Daily Soundtrack", action: "create_mixtape_daily", mood: .neutral, confidence: moodConfidence)
            ]
        }
        
        return actions
    }
}
