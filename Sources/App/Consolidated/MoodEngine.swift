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
import Domain
import Vision
import CoreData
import Combine
import AVFoundation
import Intents
import os.log
import SharedTypes

// Mood enum is now defined in SharedTypes.swift
// Here we add domain-specific mood analysis capabilities
extension Mood {
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

/// A service for analyzing and detecting mood in audio content.
///
/// The MoodEngine provides real-time mood analysis of audio content using
/// machine learning and signal processing techniques.
///
/// ## Overview
///
/// MoodEngine analyzes audio features to determine emotional characteristics
/// and provides mood-based recommendations:
///
/// ```swift
/// let engine = MoodEngine.shared
///
/// // Analyze audio file
/// let mood = try await engine.detectMood(from: audioURL)
///
/// // Get mood-based recommendations
/// let recommendations = try await engine.getRecommendations(
///     matching: mood,
///     limit: 5
/// )
/// ```
///
/// ## Topics
///
/// ### Essentials
/// - ``shared``
/// - ``detectMood(from:)``
///
/// ### Mood Analysis
/// - ``currentMood``
/// - ``moodHistory``
/// - ``confidence``
///
/// ### Recommendations
/// - ``getRecommendations(matching:limit:)``
/// - ``generateMoodBasedPlaylist(duration:)``
///
/// ### Configuration
/// - ``configure(_:)``
/// - ``reset()``
public final class MoodEngine: ObservableObject {
    // MARK: - Published Properties
    
    /// Current detected mood state
    @Published private(set) var currentMood: Mood = .neutral
    
    /// Confidence level in current mood detection (0.0-1.0)
    @Published private(set) var moodConfidence: Float = 0.0
    
    /// History of recently detected moods
    @Published private(set) var recentMoods: [Mood] = []
    
    /// Detailed mood distribution (percentage of each mood type)
    @Published private(set) var moodDistribution: [Mood: Float] = [:]
    
    /// Current mood detection state
    @Published private(set) var detectionState: DetectionState = .inactive
    
    /// Whether to adapt to user listening context
    @Published var adaptToContext: Bool = true {
        didSet {
            UserDefaults.standard.set(adaptToContext, forKey: "MoodEngine.adaptToContext")
        }
    }
    
    /// Whether to use enhanced features
    @Published var useEnhancedFeatures: Bool = true {
        didSet {
            UserDefaults.standard.set(useEnhancedFeatures, forKey: "MoodEngine.useEnhancedFeatures")
        }
    }
    
    // MARK: - Private Properties
    
    /// Logger for mood engine operations
    private let logger = Logger(subsystem: "com.mixtapes.ai", category: "MoodEngine")
    
    /// Audio processor for feature extraction
    private let audioProcessor: AudioProcessor
    
    /// Audio analysis service
    private let analysisService: AudioAnalysisService
    
    /// ML model for mood classification
    private var moodClassifier: MoodClassifier?
    
    /// Classifier confidence threshold
    private let confidenceThreshold: Float = 0.65
    
    /// Maximum number of recent moods to track
    private let maxRecentMoods = 10
    
    /// Mood stability factor (higher = more stable)
    private let moodStabilityFactor: Float = 0.7
    
    /// Cancellables for subscription management
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(audioProcessor: AudioProcessor? = nil, analysisService: AudioAnalysisService? = nil) {
        self.audioProcessor = audioProcessor ?? AudioProcessor()
        self.analysisService = analysisService ?? AudioAnalysisService()
        
        // Load user preferences
        self.adaptToContext = UserDefaults.standard.bool(forKey: "MoodEngine.adaptToContext")
        self.useEnhancedFeatures = UserDefaults.standard.bool(forKey: "MoodEngine.useEnhancedFeatures")
        
        // Initialize mood distribution
        initializeMoodDistribution()
        
        // Set up model
        setupMoodClassifier()
        
        // Set up audio processor subscription
        setupAudioProcessorSubscription()
    }
    
    // MARK: - Setup Methods
    
    /// Initializes the mood distribution with zero values
    private func initializeMoodDistribution() {
        for mood in Mood.allCases {
            moodDistribution[mood] = 0.0
        }
    }
    
    /// Sets up the mood classifier model
    private func setupMoodClassifier() {
        do {
            moodClassifier = try MoodClassifier()
            logger.info("Mood classifier loaded successfully")
        } catch {
            logger.error("Failed to load mood classifier: \(error.localizedDescription)")
        }
    }
    
    /// Sets up subscription to audio processor updates
    private func setupAudioProcessorSubscription() {
        // Subscribe to audio features updates
        NotificationCenter.default.publisher(for: .audioFeaturesUpdated)
            .compactMap { $0.object as? AudioFeatures }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] features in
                self?.processFeaturesUpdate(features)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Starts real-time mood detection
    func startMoodDetection() {
        guard detectionState == .inactive else {
            logger.info("Mood detection already active")
            return
        }
        
        detectionState = .active
        
        // Start audio processor if needed
        if !audioProcessor.isAnalyzing {
            audioProcessor.startRealTimeAnalysis { [weak self] features in
                self?.processFeaturesUpdate(features)
            }
        }
        
        logger.info("Mood detection started")
    }
    
    /// Stops real-time mood detection
    func stopMoodDetection() {
        guard detectionState != .inactive else { return }
        
        detectionState = .inactive
        
        // Stop audio processor if needed
        if audioProcessor.isAnalyzing {
            audioProcessor.stopRealTimeAnalysis()
        }
        
        logger.info("Mood detection stopped")
    }
    
    /// Analyzes a song file to detect its mood
    /// - Parameter url: URL to the song file
    /// - Returns: The detected mood and confidence level
    func analyzeSong(at url: URL) async throws -> (mood: Mood, confidence: Float) {
        detectionState = .analyzing
        
        defer {
            DispatchQueue.main.async {
                self.detectionState = self.detectionState == .analyzing ? .inactive : self.detectionState
            }
        }
        
        // Analyze audio features from file
        let audioFeatures = try await analysisService.analyzeAudioFile(at: url)
        
        // Detect mood from features
        let result = detectMoodFromFeatures(audioFeatures)
        
        DispatchQueue.main.async {
            // Update last analyzed mood but don't change current mood
            self.updateRecentMoods(with: result.mood)
            self.updateMoodDistribution(with: result.mood, confidence: result.confidence)
        }
        
        return result
    }
    
    /// Gets recommendations based on the current mood
    /// - Parameter limit: Maximum number of recommendations to return
    /// - Returns: Array of mood-based actions or recommendations
    func getMoodRecommendations(limit: Int = 3) -> [MoodAction] {
        // Create recommendations based on current mood
        var recommendations: [MoodAction] = []
        
        // Get current time of day context
        let timeContext = getTimeOfDayContext()
        
        // Create recommendations specific to mood and time context
        switch currentMood {
        case .energetic:
            recommendations.append(MoodAction(
                title: "Workout Mix",
                action: "Create an energetic playlist for working out",
                mood: .energetic,
                confidence: moodConfidence
            ))
            
            if timeContext == .morning {
                recommendations.append(MoodAction(
                    title: "Morning Boost",
                    action: "Create an upbeat playlist to start your day",
                    mood: .energetic,
                    confidence: moodConfidence
                ))
            }
            
        case .relaxed:
            recommendations.append(MoodAction(
                title: "Chill Session",
                action: "Create a relaxing playlist for unwinding",
                mood: .relaxed,
                confidence: moodConfidence
            ))
            
            if timeContext == .evening || timeContext == .night {
                recommendations.append(MoodAction(
                    title: "Sleep Sounds",
                    action: "Create a calm playlist for bedtime",
                    mood: .relaxed,
                    confidence: moodConfidence
                ))
            }
            
        case .happy:
            recommendations.append(MoodAction(
                title: "Feel Good Mix",
                action: "Create an uplifting playlist with positive vibes",
                mood: .happy,
                confidence: moodConfidence
            ))
            
            recommendations.append(MoodAction(
                title: "Party Starter",
                action: "Create a playlist for social gatherings",
                mood: .happy,
                confidence: moodConfidence
            ))
            
        case .melancholic:
            recommendations.append(MoodAction(
                title: "Reflective Journey",
                action: "Create a thoughtful playlist for introspection",
                mood: .melancholic,
                confidence: moodConfidence
            ))
            
            recommendations.append(MoodAction(
                title: "Rainy Day",
                action: "Create a moody playlist for cloudy days",
                mood: .melancholic,
                confidence: moodConfidence
            ))
            
        case .focused:
            recommendations.append(MoodAction(
                title: "Deep Work",
                action: "Create a productivity playlist for concentration",
                mood: .focused,
                confidence: moodConfidence
            ))
            
            recommendations.append(MoodAction(
                title: "Study Session",
                action: "Create a playlist for academic focus",
                mood: .focused,
                confidence: moodConfidence
            ))
            
        case .romantic:
            recommendations.append(MoodAction(
                title: "Date Night",
                action: "Create a romantic playlist for special moments",
                mood: .romantic,
                confidence: moodConfidence
            ))
            
            if timeContext == .evening {
                recommendations.append(MoodAction(
                    title: "Sunset Serenade",
                    action: "Create a playlist for evening relaxation",
                    mood: .romantic,
                    confidence: moodConfidence
                ))
            }
            
        case .angry:
            recommendations.append(MoodAction(
                title: "Release",
                action: "Create an intense playlist to channel emotions",
                mood: .angry,
                confidence: moodConfidence
            ))
            
            recommendations.append(MoodAction(
                title: "Power Hour",
                action: "Create a high-energy playlist for motivation",
                mood: .angry,
                confidence: moodConfidence
            ))
            
        case .neutral:
            recommendations.append(MoodAction(
                title: "Balanced Mix",
                action: "Create a versatile playlist for any occasion",
                mood: .neutral,
                confidence: moodConfidence
            ))
            
            // Add a recommendation based on time of day
            switch timeContext {
            case .morning:
                recommendations.append(MoodAction(
                    title: "Morning Blend",
                    action: "Create a balanced playlist to start your day",
                    mood: .neutral,
                    confidence: moodConfidence
                ))
            case .afternoon:
                recommendations.append(MoodAction(
                    title: "Midday Mix",
                    action: "Create a playlist for afternoon activities",
                    mood: .neutral,
                    confidence: moodConfidence
                ))
            case .evening:
                recommendations.append(MoodAction(
                    title: "Evening Unwind",
                    action: "Create a playlist for winding down",
                    mood: .neutral,
                    confidence: moodConfidence
                ))
            case .night:
                recommendations.append(MoodAction(
                    title: "Night Owl",
                    action: "Create a playlist for late-night sessions",
                    mood: .neutral,
                    confidence: moodConfidence
                ))
            }
        }
        
        // Add a personalized recommendation based on user history
        if let preferredMood = getPreferredMood() {
            recommendations.append(MoodAction(
                title: "Just For You",
                action: "Create a \(preferredMood.rawValue.lowercased()) playlist based on your history",
                mood: preferredMood,
                confidence: 0.9
            ))
        }
        
        // Limit results
        return Array(recommendations.prefix(limit))
    }
    
    /// Generates a mood-based playlist name
    /// - Returns: A suggested name for a mood-based playlist
    func generateMoodBasedPlaylistName() -> String {
        let descriptors = currentMood.keywords.shuffled().prefix(2)
        
        let timeContext = getTimeOfDayContext()
        var timePrefix = ""
        
        switch timeContext {
        case .morning:
            timePrefix = ["Morning", "Dawn", "Sunrise", "Early"].randomElement() ?? ""
        case .afternoon:
            timePrefix = ["Afternoon", "Midday", "Daytime"].randomElement() ?? ""
        case .evening:
            timePrefix = ["Evening", "Sunset", "Dusk"].randomElement() ?? ""
        case .night:
            timePrefix = ["Night", "Midnight", "Nocturnal"].randomElement() ?? ""
        }
        
        // Generate name with a 50% chance of including the time prefix
        if Bool.random() && !timePrefix.isEmpty {
            return "\(timePrefix) \(descriptors.joined(separator: " ").capitalized)"
        } else {
            // Otherwise use one of these formats
            let formats = [
                "\(currentMood.rawValue) \(descriptors.first?.capitalized ?? "Mix")",
                "\(descriptors.joined(separator: " ").capitalized)",
                "The \(currentMood.rawValue) Collection",
                "\(currentMood.rawValue) Journey",
                "My \(currentMood.rawValue) Mood"
            ]
            
            return formats.randomElement() ?? "\(currentMood.rawValue) Mix"
        }
    }
    
    // MARK: - Feature Processing
    
    /// Processes audio feature updates from the audio processor
    /// - Parameter features: Updated audio features
    private func processFeaturesUpdate(_ features: AudioFeatures) {
        guard detectionState == .active else { return }
        
        // Detect mood from features
        let result = detectMoodFromFeatures(features)
        
        // Update mood state with stability factor
        updateMood(result.mood, confidence: result.confidence)
    }
    
    /// Detects mood from audio features
    /// - Parameter features: Audio features to analyze
    /// - Returns: Tuple containing detected mood and confidence level
    private func detectMoodFromFeatures(_ features: AudioFeatures) -> Mood {
        var moodScores: [(mood: Mood, score: Float)] = []
        
        // Energetic
        moodScores.append((.energetic, calculateEnergeticScore(features)))
        
        // Relaxed
        moodScores.append((.relaxed, calculateRelaxedScore(features)))
        
        // Happy
        moodScores.append((.happy, calculateHappyScore(features)))
        
        // Melancholic
        moodScores.append((.melancholic, calculateMelancholicScore(features)))
        
        // Focused
        moodScores.append((.focused, calculateFocusedScore(features)))
        
        // Find highest scoring mood
        moodScores.sort { $0.score > $1.score }
        return moodScores.first?.mood ?? .neutral
    }
    
    private func calculateEnergeticScore(_ features: AudioFeatures) -> Float {
        return min(1.0, (
            features.energy * 0.4 +
            (features.tempo / 180.0) * 0.3 +
            features.danceability * 0.3
        ))
    }
    
    private func calculateRelaxedScore(_ features: AudioFeatures) -> Float {
        return min(1.0, (
            (1.0 - features.energy) * 0.4 +
            features.acousticness * 0.3 +
            (1.0 - features.tempo / 120.0) * 0.3
        ))
    }
    
    private func calculateHappyScore(_ features: AudioFeatures) -> Float {
        return min(1.0, (
            features.valence * 0.4 +
            features.energy * 0.3 +
            features.danceability * 0.3
        ))
    }
    
    private func calculateMelancholicScore(_ features: AudioFeatures) -> Float {
        return min(1.0, (
            (1.0 - features.valence) * 0.4 +
            (1.0 - features.energy) * 0.3 +
            features.acousticness * 0.3
        ))
    }
    
    private func calculateFocusedScore(_ features: AudioFeatures) -> Float {
        return min(1.0, (
            features.instrumentalness * 0.4 +
            (1.0 - features.speechiness) * 0.3 +
            (0.5 - abs(0.5 - features.energy)) * 0.3
        ))
    }
    
    // MARK: - Enhanced Mood Detection Methods
    
    /// Extracts mood from audio analysis with improved accuracy
    /// - Parameter audioFeatures: The features extracted from audio analysis
    /// - Returns: The detected mood and confidence level
    private func extractMoodFromAudioAnalysis(_ audioFeatures: AudioFeatures) -> (mood: Mood, confidence: Float) {
        // Start with a base confidence level for each mood
        var moodConfidence: [Mood: Float] = [:]
        for mood in Mood.allCases {
            moodConfidence[mood] = 0.0
        }
        
        // Energy-based moods
        if let energy = audioFeatures.energy {
            // High energy suggests energetic or happy
            if energy > 0.8 {
                moodConfidence[.energetic, default: 0] += 0.4
                moodConfidence[.happy, default: 0] += 0.2
                moodConfidence[.angry, default: 0] += 0.2
            } 
            // Medium energy
            else if energy > 0.5 {
                moodConfidence[.happy, default: 0] += 0.3
                moodConfidence[.focused, default: 0] += 0.2
            } 
            // Low energy suggests relaxed or melancholic
            else {
                moodConfidence[.relaxed, default: 0] += 0.3
                moodConfidence[.melancholic, default: 0] += 0.2
            }
        }
        
        // Valence-based (positivity) moods
        if let valence = audioFeatures.valence {
            // High valence is typically happy or romantic
            if valence > 0.8 {
                moodConfidence[.happy, default: 0] += 0.4
                moodConfidence[.romantic, default: 0] += 0.2
            } 
            // Medium valence
            else if valence > 0.5 {
                moodConfidence[.focused, default: 0] += 0.2
                moodConfidence[.energetic, default: 0] += 0.1
            } 
            // Low valence is typically melancholic or angry
            else {
                moodConfidence[.melancholic, default: 0] += 0.3
                moodConfidence[.angry, default: 0] += 0.2
            }
        }
        
        // Tempo-based moods (BPM)
        if let tempo = audioFeatures.tempo {
            // Fast tempo suggests energetic or focused
            if tempo > 120 {
                moodConfidence[.energetic, default: 0] += 0.3
                moodConfidence[.focused, default: 0] += 0.2
            } 
            // Medium tempo
            else if tempo > 90 {
                moodConfidence[.happy, default: 0] += 0.2
                moodConfidence[.romantic, default: 0] += 0.1
            } 
            // Slow tempo suggests relaxed or melancholic
            else {
                moodConfidence[.relaxed, default: 0] += 0.3
                moodConfidence[.melancholic, default: 0] += 0.2
                moodConfidence[.romantic, default: 0] += 0.1
            }
        }
        
        // Harmonic content (major vs minor keys)
        if let key = audioFeatures.key, let mode = audioFeatures.mode {
            // Major keys typically feel happier
            if mode > 0.5 {
                moodConfidence[.happy, default: 0] += 0.2
                moodConfidence[.energetic, default: 0] += 0.1
            } 
            // Minor keys typically feel more melancholic
            else {
                moodConfidence[.melancholic, default: 0] += 0.2
                moodConfidence[.relaxed, default: 0] += 0.1
            }
        }
        
        // Spectral features for texture analysis
        if let spectralFeatures = audioFeatures.spectralFeatures {
            // Brightness correlates with energy and focus
            if let brightness = spectralFeatures.brightness, brightness > 0.6 {
                moodConfidence[.energetic, default: 0] += 0.2
                moodConfidence[.focused, default: 0] += 0.2
            }
            
            // Roughness correlates with tension and anger
            if let roughness = spectralFeatures.roughness, roughness > 0.7 {
                moodConfidence[.angry, default: 0] += 0.3
            }
        }
        
        // Apply contextual time-of-day adjustment if enabled
        if adaptToContext {
            adjustForTimeOfDay(moodConfidence: &moodConfidence)
        }
        
        // Debug logging
        #if DEBUG
        logger.debug("Mood confidence levels: \(moodConfidence)")
        #endif
        
        // Find the mood with highest confidence
        guard let (topMood, confidence) = moodConfidence.max(by: { $0.value < $1.value }) else {
            return (.neutral, 0.5) // Default fallback
        }
        
        return (topMood, confidence)
    }
    
    /// Adjusts mood confidence based on time of day
    /// - Parameter moodConfidence: Reference to the mood confidence dictionary
    private func adjustForTimeOfDay(moodConfidence: inout [Mood: Float]) {
        let timeContext = getTimeOfDayContext()
        
        switch timeContext {
        case .morning:
            // Morning - boost energetic and focused
            moodConfidence[.energetic, default: 0] += 0.1
            moodConfidence[.focused, default: 0] += 0.1
        case .afternoon:
            // Afternoon - boost happy and focused
            moodConfidence[.happy, default: 0] += 0.1
            moodConfidence[.focused, default: 0] += 0.1
        case .evening:
            // Evening - boost relaxed and romantic
            moodConfidence[.relaxed, default: 0] += 0.1
            moodConfidence[.romantic, default: 0] += 0.1
        case .night:
            // Night - boost melancholic and relaxed
            moodConfidence[.melancholic, default: 0] += 0.1
            moodConfidence[.relaxed, default: 0] += 0.1
        }
    }
    
    /// Analyzes a sequence of songs to detect overall mixtape mood
    /// - Parameter songs: Array of songs to analyze
    /// - Returns: The dominant mood and secondary mood
    func analyzeMixtapeMood(from songs: [Song]) -> (primary: Mood, secondary: Mood?) {
        guard !songs.isEmpty else { return (.neutral, nil) }
        
        // Count occurrences of each mood
        var moodCounts: [Mood: Int] = [:]
        for mood in Mood.allCases {
            moodCounts[mood] = 0
        }
        
        // Process each song
        for song in songs {
            if let moodString = song.mood,
               let mood = Mood(rawValue: moodString) {
                moodCounts[mood, default: 0] += 1
            } else {
                moodCounts[.neutral, default: 0] += 1
            }
        }
        
        // Sort moods by count
        let sortedMoods = moodCounts.sorted { $0.value > $1.value }
        
        // Get primary and secondary moods
        let primaryMood = sortedMoods.first?.key ?? .neutral
        let secondaryMood = sortedMoods.count > 1 && sortedMoods[1].value > 0 ? sortedMoods[1].key : nil
        
        return (primaryMood, secondaryMood)
    }
    
    // MARK: - Mood State Management
    
    /// Updates the current mood, applying stability for smoother transitions
    /// - Parameters:
    ///   - newMood: The newly detected mood
    ///   - confidence: Confidence level in the detection
    private func updateMood(_ newMood: Mood, confidence: Float) {
        // Only update if confidence exceeds threshold
        guard confidence >= confidenceThreshold else {
            return
        }
        
        // Apply mood stability - only change mood if different from current with high confidence
        let shouldChange = currentMood != newMood && 
                          (confidence > moodConfidence * moodStabilityFactor)
        
        if shouldChange || currentMood == .neutral {
            DispatchQueue.main.async {
                self.currentMood = newMood
                self.moodConfidence = confidence
                self.updateRecentMoods(with: newMood)
                self.updateMoodDistribution(with: newMood, confidence: confidence)
            }
        } else {
            // Still update confidence if same mood but higher confidence
            if currentMood == newMood && confidence > moodConfidence {
                DispatchQueue.main.async {
                    self.moodConfidence = confidence
                }
            }
        }
    }
    
    /// Updates the recent moods history
    /// - Parameter mood: The mood to add to history
    private func updateRecentMoods(with mood: Mood) {
        recentMoods.insert(mood, at: 0)
        if recentMoods.count > maxRecentMoods {
            recentMoods.removeLast()
        }
    }
    
    /// Updates the mood distribution percentages
    /// - Parameters:
    ///   - mood: The mood to update
    ///   - confidence: Confidence level in the detection
    private func updateMoodDistribution(with mood: Mood, confidence: Float) {
        // Apply decay factor to existing values
        let decayFactor: Float = 0.95
        for key in moodDistribution.keys {
            moodDistribution[key] = (moodDistribution[key] ?? 0) * decayFactor
        }
        
        // Add new mood detection
        moodDistribution[mood] = (moodDistribution[mood] ?? 0) + (confidence * 0.5)
        
        // Normalize distribution to sum to 1.0
        let total = moodDistribution.values.reduce(0, +)
        if total > 0 {
            for key in moodDistribution.keys {
                moodDistribution[key] = (moodDistribution[key] ?? 0) / total
            }
        }
    }
    
    /// Gets the user's preferred mood based on history
    /// - Returns: The most common mood in recent history
    private func getPreferredMood() -> Mood? {
        // Count mood occurrences
        var counts: [Mood: Int] = [:]
        for mood in recentMoods {
            counts[mood, default: 0] += 1
        }
        
        // Return most frequent mood
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    // MARK: - Context Helpers
    
    /// Gets the current time of day context
    /// - Returns: The current time context
    private func getTimeOfDayContext() -> TimeContext {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<22:
            return .evening
        default:
            return .night
        }
    }
}

// MARK: - Supporting Types

/// Enum representing time of day context
enum TimeContext {
    case morning
    case afternoon
    case evening
    case night
}

/// Enum representing mood detection state
enum DetectionState {
    case inactive
    case active
    case analyzing
}

/// ML model wrapper for mood classification
class MoodClassifier {
    // This would normally be implemented with a Core ML model
    // For now, it's just a placeholder
    
    func prediction(energy: Float, valence: Float, tempo: Float, 
                   danceability: Float, acousticness: Float) throws -> MoodPrediction {
        // Simple rule-based classification as a fallback
        // In a real implementation, this would use the ML model
        
        let moodString: String
        var confidence: Float = 0.7 // Default confidence
        
        if energy > 0.7 && valence > 0.7 {
            moodString = "Happy"
            confidence = 0.8
        } else if energy > 0.7 && valence < 0.4 {
            moodString = "Angry"
            confidence = 0.75
        } else if energy > 0.7 {
            moodString = "Energetic"
            confidence = 0.8
        } else if energy < 0.4 && valence > 0.5 {
            moodString = "Relaxed"
            confidence = 0.8
        } else if energy < 0.4 && valence < 0.4 {
            moodString = "Melancholic"
            confidence = 0.75
        } else if danceability > 0.7 && valence > 0.6 {
            moodString = "Happy"
            confidence = 0.7
        } else if acousticness > 0.7 && valence > 0.5 {
            moodString = "Romantic"
            confidence = 0.7
        } else if tempo < 90 && energy < 0.5 {
            moodString = "Relaxed"
            confidence = 0.7
        } else if tempo > 120 && energy > 0.6 {
            moodString = "Energetic"
            confidence = 0.7
        } else {
            moodString = "Neutral"
            confidence = 0.6
        }
        
        return MoodPrediction(mood: moodString, confidence: confidence)
    }
}

/// Struct representing a mood prediction result
struct MoodPrediction {
    let mood: String?
    let confidence: Float?
}

// MARK: - Notification Extensions

extension Notification.Name {
    /// Posted when audio features are updated
    static let audioFeaturesUpdated = Notification.Name("audioFeaturesUpdated")
    
    /// Posted when mood detection state changes
    static let moodDetectionStateChanged = Notification.Name("moodDetectionStateChanged")
}
