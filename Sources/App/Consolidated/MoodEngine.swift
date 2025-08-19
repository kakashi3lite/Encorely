//  MoodEngine.swift
//  Central adaptive model: fuses audio features, user interactions, personality bias,
//  and external context (sensor + hint APIs) to maintain current mood & distribution.
//  Large by necessity today; roadmap includes slicing into: Core State, Feature Extraction,
//  Adaptation Policies, Persistence/History, and External Integrations.

import AVFoundation
import Combine
import CoreData
import CoreML
import Foundation
import Intents
import os.log
import SwiftUI
import Vision

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
        adaptToContext = UserDefaults.standard.bool(forKey: "MoodEngine.adaptToContext")
        useEnhancedFeatures = UserDefaults.standard.bool(forKey: "MoodEngine.useEnhancedFeatures")

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
        if Bool.random(), !timePrefix.isEmpty {
            return "\(timePrefix) \(descriptors.joined(separator: " ").capitalized)"
        } else {
            // Otherwise use one of these formats
            let formats = [
                "\(currentMood.rawValue) \(descriptors.first?.capitalized ?? "Mix")",
                "\(descriptors.joined(separator: " ").capitalized)",
                "The \(currentMood.rawValue) Collection",
                "\(currentMood.rawValue) Journey",
                "My \(currentMood.rawValue) Mood",
            ]

            return formats.randomElement() ?? "\(currentMood.rawValue) Mix"
        }
    }

    // Feature processing logic extracted to MoodEngine+Detection.swift

    // Advanced detection & contextual adjustments extracted to MoodEngine+Detection.swift

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
               let mood = Mood(rawValue: moodString)
            {
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

    // State management helpers extracted to MoodEngine+State.swift

    // MARK: - Context Helpers

    // Time context helper moved to MoodEngine+Detection.swift
}

// Remaining components moved to dedicated extension files (MoodEngine+*)
