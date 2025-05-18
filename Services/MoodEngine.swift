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
import CoreData
import Combine
import AVFoundation
import Intents

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
    // Dependencies
    private let moc: NSManagedObjectContext
    private let audioProcessor: AudioProcessor
    
    // Error handling
    private let errorSubject = PassthroughSubject<AppError, Never>()
    var errorPublisher: AnyPublisher<AppError, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    // Mood state
    @Published private(set) var currentMood: Mood = .neutral
    @Published private(set) var moodConfidence: Float = 0.0
    @Published private(set) var moodHistory: [MoodSnapshot] = []
    
    // Analysis settings
    private let analysisInterval: TimeInterval = 300 // 5 minutes
    private let minSamplesForAnalysis = 3
    private var analysisTimer: Timer?
    private var audioFeatureBuffer: [AudioFeatures] = []
    
    init(context: NSManagedObjectContext, audioProcessor: AudioProcessor) {
        self.moc = context
        self.audioProcessor = audioProcessor
        setupAnalysis()
    }
    
    // MARK: - Public Interface
    
    /// Start continuous mood analysis
    func startAnalysis() throws {
        do {
            try audioProcessor.startRealTimeAnalysis { [weak self] features in
                self?.processAudioFeatures(features)
            }
        } catch {
            errorSubject.send(error as? AppError ?? .audioProcessingFailed(error))
            throw error
        }
    }
    
    /// Stop mood analysis
    func stopAnalysis() {
        audioProcessor.stopRealTimeAnalysis()
        analysisTimer?.invalidate()
        analysisTimer = nil
    }
    
    /// Get the current mood intensity (0-1)
    func getMoodIntensity() -> Float {
        switch currentMood {
        case .energetic:
            return calculateEnergyIntensity()
        case .relaxed:
            return calculateRelaxationIntensity()
        case .happy:
            return calculateHappinessIntensity()
        case .melancholic:
            return calculateMelancholyIntensity()
        case .focused:
            return calculateFocusIntensity()
        case .romantic:
            return calculateRomanceIntensity()
        case .angry:
            return calculateAngerIntensity()
        case .neutral:
            return 0.5
        }
    }
    
    /// Get mood suggestions for the current context
    func getMoodSuggestions() -> [Mood] {
        do {
            // Get recent listening history
            let history = try getRecentHistory()
            
            // Analyze mood patterns
            let patterns = try analyzeMoodPatterns(in: history)
            
            // Get time-based suggestions
            let timeSuggestions = getTimeBasedSuggestions()
            
            // Combine and return top suggestions
            return rankMoodSuggestions(patterns: patterns, timeSuggestions: timeSuggestions)
            
        } catch {
            errorSubject.send(error as? AppError ?? .moodAnalysisFailed)
            return [.neutral]
        }
    }
    
    /// Get a description of how the current mood affects music selection
    func getMoodInfluenceDescription() -> String {
        switch currentMood {
        case .energetic:
            return "Prioritizing upbeat tempos and high-energy tracks to maintain momentum"
        case .relaxed:
            return "Focusing on calm, soothing melodies and gentle rhythms"
        case .happy:
            return "Selecting positive, uplifting songs with bright tonality"
        case .melancholic:
            return "Choosing emotionally resonant songs with deeper themes"
        case .focused:
            return "Curating minimal, non-distracting tracks ideal for concentration"
        case .romantic:
            return "Highlighting intimate, atmospheric songs with emotional depth"
        case .angry:
            return "Featuring intense, cathartic tracks with strong rhythms"
        case .neutral:
            return "Balancing various musical elements for a versatile listening experience"
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupAnalysis() {
        analysisTimer = Timer.scheduledTimer(withTimeInterval: analysisInterval, repeats: true) { [weak self] _ in
            self?.analyzeMood()
        }
    }
    
    private func processAudioFeatures(_ features: AudioFeatures) {
        audioFeatureBuffer.append(features)
        
        // Keep buffer size manageable
        if audioFeatureBuffer.count > minSamplesForAnalysis * 2 {
            audioFeatureBuffer.removeFirst()
        }
    }
    
    private func analyzeMood() {
        guard audioFeatureBuffer.count >= minSamplesForAnalysis else {
            errorSubject.send(.insufficientData)
            return
        }
        
        do {
            let features = try averageFeatures()
            let mood = try determineOverallMood(from: features)
            updateCurrentMood(mood)
            saveSnapshot()
            
        } catch {
            errorSubject.send(error as? AppError ?? .moodAnalysisFailed)
        }
    }
    
    private func averageFeatures() throws -> AudioFeatures {
        guard !audioFeatureBuffer.isEmpty else {
            throw AppError.insufficientData
        }
        
        let count = Float(audioFeatureBuffer.count)
        
        let energy = audioFeatureBuffer.reduce(0) { $0 + $1.energy } / count
        let valence = audioFeatureBuffer.reduce(0) { $0 + $1.valence } / count
        let danceability = audioFeatureBuffer.reduce(0) { $0 + $1.danceability } / count
        let acousticness = audioFeatureBuffer.reduce(0) { $0 + $1.acousticness } / count
        let instrumentalness = audioFeatureBuffer.reduce(0) { $0 + $1.instrumentalness } / count
        let speechiness = audioFeatureBuffer.reduce(0) { $0 + $1.speechiness } / count
        let liveness = audioFeatureBuffer.reduce(0) { $0 + $1.liveness } / count
        let tempo = audioFeatureBuffer.reduce(0) { $0 + $1.tempo } / count
        
        return AudioFeatures(
            energy: energy,
            valence: valence,
            danceability: danceability,
            acousticness: acousticness,
            instrumentalness: instrumentalness,
            speechiness: speechiness,
            liveness: liveness,
            tempo: tempo
        )
    }
    
    private func determineOverallMood(from features: AudioFeatures) throws -> Mood {
        // Calculate mood scores using all available features
        var moodScores: [Mood: Float] = [:]
        
        moodScores[.energetic] = (
            features.energy * 0.4 +
            features.danceability * 0.3 +
            (features.tempo / 180.0) * 0.2 +
            features.liveness * 0.1
        )
        
        moodScores[.relaxed] = (
            (1 - features.energy) * 0.3 +
            features.acousticness * 0.3 +
            (1 - features.tempo / 180.0) * 0.2 +
            (1 - features.danceability) * 0.2
        )
        
        moodScores[.happy] = (
            features.valence * 0.4 +
            features.energy * 0.3 +
            features.danceability * 0.2 +
            (1 - features.speechiness) * 0.1
        )
        
        moodScores[.melancholic] = (
            (1 - features.valence) * 0.4 +
            features.acousticness * 0.3 +
            (1 - features.danceability) * 0.2 +
            (1 - features.energy) * 0.1
        )
        
        moodScores[.focused] = (
            features.instrumentalness * 0.4 +
            (1 - features.speechiness) * 0.3 +
            calculateEnergyBalance(features.energy) * 0.2 +
            (1 - features.liveness) * 0.1
        )
        
        moodScores[.romantic] = (
            features.valence * 0.3 +
            features.acousticness * 0.3 +
            (1 - features.energy) * 0.2 +
            (1 - features.instrumentalness) * 0.2
        )
        
        moodScores[.angry] = (
            features.energy * 0.4 +
            (1 - features.valence) * 0.3 +
            (features.tempo / 180.0) * 0.2 +
            (1 - features.acousticness) * 0.1
        )
        
        moodScores[.neutral] = (
            (1 - abs(features.energy - 0.5)) * 0.3 +
            (1 - abs(features.valence - 0.5)) * 0.3 +
            (1 - abs(features.danceability - 0.5)) * 0.2 +
            (1 - abs(features.acousticness - 0.5)) * 0.2
        )
        
        // Find mood with highest score
        guard let (dominantMood, score) = moodScores.max(by: { $0.value < $1.value }),
              score > 0.4 else { // Require minimum confidence
            return .neutral
        }
        
        return dominantMood
    }
    
    private func updateCurrentMood(_ newMood: Mood) {
        // Only update if confidence is high enough
        if moodConfidence >= 0.6 {
            currentMood = newMood
        }
    }
    
    private func saveSnapshot() {
        let snapshot = MoodSnapshot(
            mood: currentMood,
            confidence: moodConfidence,
            timestamp: Date()
        )
        
        moodHistory.append(snapshot)
        
        // Keep history manageable
        if moodHistory.count > 100 {
            moodHistory.removeFirst()
        }
    }
    
    private func getRecentHistory() throws -> [MoodSnapshot] {
        // Get snapshots from last 24 hours
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        return moodHistory.filter { $0.timestamp >= cutoff }
    }
    
    private func analyzeMoodPatterns(in history: [MoodSnapshot]) throws -> [Mood: Int] {
        guard !history.isEmpty else {
            throw AppError.insufficientData
        }
        
        var patterns: [Mood: Int] = [:]
        for snapshot in history {
            patterns[snapshot.mood, default: 0] += 1
        }
        
        return patterns
    }
    
    private func getTimeBasedSuggestions() -> [Mood] {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<9: // Morning
            return [.energetic, .focused, .happy]
        case 9..<12: // Late morning
            return [.focused, .happy, .neutral]
        case 12..<14: // Lunch
            return [.relaxed, .happy, .neutral]
        case 14..<17: // Afternoon
            return [.focused, .energetic, .neutral]
        case 17..<20: // Evening
            return [.relaxed, .romantic, .happy]
        case 20..<23: // Night
            return [.relaxed, .melancholic, .romantic]
        default: // Late night
            return [.relaxed, .melancholic, .focused]
        }
    }
    
    private func rankMoodSuggestions(patterns: [Mood: Int], timeSuggestions: [Mood]) -> [Mood] {
        var rankedMoods: [(mood: Mood, score: Float)] = []
        
        for mood in Mood.allCases {
            var score: Float = 0
            
            // Pattern score (0-50)
            if let patternCount = patterns[mood] {
                score += Float(patternCount * 10)
            }
            
            // Time relevance score (0-30)
            if timeSuggestions.contains(mood) {
                score += 30
            }
            
            // Current mood compatibility score (0-20)
            score += getMoodCompatibilityScore(mood)
            
            rankedMoods.append((mood: mood, score: score))
        }
        
        // Sort by score and return top moods
        return rankedMoods
            .sorted { $0.score > $1.score }
            .prefix(3)
            .map { $0.mood }
    }
    
    private func getMoodCompatibilityScore(_ mood: Mood) -> Float {
        switch (currentMood, mood) {
        case (.energetic, .happy),
             (.happy, .energetic),
             (.relaxed, .focused),
             (.focused, .relaxed),
             (.romantic, .happy),
             (.happy, .romantic):
            return 20 // High compatibility
            
        case (.melancholic, .angry),
             (.angry, .melancholic),
             (.energetic, .relaxed),
             (.relaxed, .energetic):
            return 5 // Low compatibility
            
        case (_, .neutral),
             (.neutral, _):
            return 15 // Medium compatibility with neutral
            
        default:
            return 10 // Default medium compatibility
        }
    }
    
    // MARK: - Intensity Calculations
    
    private func calculateEnergyIntensity() -> Float {
        guard !audioFeatureBuffer.isEmpty else { return 0.5 }
        return audioFeatureBuffer.last?.energy ?? 0.5
    }
    
    private func calculateRelaxationIntensity() -> Float {
        guard !audioFeatureBuffer.isEmpty else { return 0.5 }
        return 1 - (audioFeatureBuffer.last?.energy ?? 0.5)
    }
    
    private func calculateHappinessIntensity() -> Float {
        guard !audioFeatureBuffer.isEmpty else { return 0.5 }
        return audioFeatureBuffer.last?.valence ?? 0.5
    }
    
    private func calculateMelancholyIntensity() -> Float {
        guard !audioFeatureBuffer.isEmpty else { return 0.5 }
        return 1 - (audioFeatureBuffer.last?.valence ?? 0.5)
    }
    
    private func calculateFocusIntensity() -> Float {
        guard !audioFeatureBuffer.isEmpty else { return 0.5 }
        let features = audioFeatureBuffer.last!
        return (features.instrumentalness + (1 - features.speechiness)) / 2
    }
    
    private func calculateRomanceIntensity() -> Float {
        guard !audioFeatureBuffer.isEmpty else { return 0.5 }
        let features = audioFeatureBuffer.last!
        return (features.valence + features.acousticness) / 2
    }
    
    private func calculateAngerIntensity() -> Float {
        guard !audioFeatureBuffer.isEmpty else { return 0.5 }
        let features = audioFeatureBuffer.last!
        return (features.energy + (1 - features.valence)) / 2
    }
    
    // MARK: - Siri Integration
    
    func handleSiriMoodRequest(_ intent: PlayMoodIntent) -> Mood {
        guard let moodParam = intent.mood,
              let identifier = moodParam.identifier,
              let mood = Mood(rawValue: identifier) else {
            return .neutral
        }
        return mood
    }
    
    func getSiriMoodParameter(_ mood: Mood) -> MoodParameter {
        MoodParameter(identifier: mood.rawValue, display: mood.displayName)
    }
    
    // MARK: - Mood Detection
    
    func detectMoodFromAudioFeatures(tempo: Double, energy: Float, valence: Float) {
        let mood = determineMoodFromFeatures(tempo: tempo, energy: energy, valence: valence)
        setMood(mood, confidence: 0.8)
    }
    
    func updateMoodBasedOnTimeOfDay() {
        let hour = Calendar.current.component(.hour, from: Date())
        let suggestedMood: Mood
        
        switch hour {
        case 5..<9: suggestedMood = .energetic  // Morning
        case 9..<12: suggestedMood = .focused   // Late morning
        case 12..<14: suggestedMood = .happy    // Lunch
        case 14..<17: suggestedMood = .focused  // Afternoon
        case 17..<20: suggestedMood = .relaxed  // Evening
        case 20..<23: suggestedMood = .romantic // Night
        default: suggestedMood = .neutral       // Late night
        }
        
        // Lower confidence for time-based suggestions
        setMood(suggestedMood, confidence: 0.4)
    }
    
    // MARK: - Private Methods
    
    private func determineMoodFromFeatures(tempo: Double, energy: Float, valence: Float) -> Mood {
        // Simple mood determination logic based on audio features
        if energy > 0.8 {
            return .energetic
        } else if energy < 0.3 {
            return .relaxed
        } else if valence > 0.7 {
            return .happy
        } else if valence < 0.3 {
            return .melancholic
        } else if tempo > 120 {
            return .focused
        } else {
            return .neutral
        }
    }
    
    func processInteraction(_ event: InteractionEvent) throws {
        // Update mood confidence based on interaction
        if event.type.contains("mood_") {
            moodConfidence = min(moodConfidence + 0.1, 1.0)
        }
    }
}

// MARK: - Supporting Types

struct MoodSnapshot {
    let mood: Mood
    let confidence: Float
    let timestamp: Date
}

extension Mood {
    var description: String {
        switch self {
        case .energetic:
            return "High energy and upbeat"
        case .relaxed:
            return "Calm and peaceful"
        case .happy:
            return "Positive and joyful"
        case .melancholic:
            return "Reflective and emotional"
        case .focused:
            return "Concentrated and clear"
        case .romantic:
            return "Intimate and passionate"
        case .angry:
            return "Intense and powerful"
        case .neutral:
            return "Balanced and moderate"
        }
    }
    
    var icon: String {
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
    
    var color: Color {
        switch self {
        case .energetic: return .yellow
        case .relaxed: return .mint
        case .happy: return .orange
        case .melancholic: return .blue
        case .focused: return .purple
        case .romantic: return .pink
        case .angry: return .red
        case .neutral: return .gray
        }
    }
}
