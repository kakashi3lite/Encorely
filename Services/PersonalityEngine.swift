//
//  PersonalityEngine.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import CoreML

/// Enum representing different user personality types for UI/UX adaptation
enum PersonalityType: String, CaseIterable {
    case explorer = "Explorer"   // Values discovery and variety
    case curator = "Curator"     // Values organization and quality
    case enthusiast = "Enthusiast" // Values deep dives and expertise
    case social = "Social"       // Values sharing and connecting
    case ambient = "Ambient"     // Values background/passive use
    case analyzer = "Analyzer"   // Values technical details and control
    case neutral = "Neutral"     // Neutral personality type
    
    /// Returns a theme color associated with each personality type
    var themeColor: Color {
        switch self {
        case .explorer: return Color.blue
        case .curator: return Color.purple
        case .enthusiast: return Color.orange
        case .social: return Color.green
        case .ambient: return Color.teal
        case .analyzer: return Color.gray
        case .neutral: return Color.secondary
        }
    }
    
    /// Returns UI preferences for each personality type
    var uiPreferences: UIPreferences {
        switch self {
        case .explorer:
            return UIPreferences(
                listStyle: .grid,
                showRecommendations: true,
                defaultSortOrder: .recommended,
                featuredSectionSize: .large,
                detailLevel: .medium,
                navigationStyle: .tabbed
            )
        case .curator:
            return UIPreferences(
                listStyle: .list,
                showRecommendations: false,
                defaultSortOrder: .manual,
                featuredSectionSize: .small,
                detailLevel: .high,
                navigationStyle: .hierarchical
            )
        case .enthusiast:
            return UIPreferences(
                listStyle: .detailed,
                showRecommendations: true,
                defaultSortOrder: .alphabetical,
                featuredSectionSize: .medium,
                detailLevel: .maximum,
                navigationStyle: .hierarchical
            )
        case .social:
            return UIPreferences(
                listStyle: .card,
                showRecommendations: true,
                defaultSortOrder: .recentlyPlayed,
                featuredSectionSize: .large,
                detailLevel: .low,
                navigationStyle: .tabbed
            )
        case .ambient:
            return UIPreferences(
                listStyle: .minimal,
                showRecommendations: true,
                defaultSortOrder: .recommended,
                featuredSectionSize: .small,
                detailLevel: .low,
                navigationStyle: .contextual
            )
        case .analyzer:
            return UIPreferences(
                listStyle: .detailed,
                showRecommendations: false,
                defaultSortOrder: .manual,
                featuredSectionSize: .none,
                detailLevel: .maximum,
                navigationStyle: .hierarchical
            )
        case .neutral:
            return UIPreferences(
                listStyle: .list,
                showRecommendations: true,
                defaultSortOrder: .recommended,
                featuredSectionSize: .medium,
                detailLevel: .medium,
                navigationStyle: .tabbed
            )
        }
    }
    
    /// Returns interaction preferences for each personality type
    var interactionPreferences: InteractionPreferences {
        switch self {
        case .explorer:
            return InteractionPreferences(
                autoPlayEnabled: true,
                crossfadeDuration: 2.0,
                suggestionsFrequency: .high,
                gestureComplexity: .high,
                voiceControlPriority: .medium,
                defaultViewMode: .discovery
            )
        case .curator:
            return InteractionPreferences(
                autoPlayEnabled: false,
                crossfadeDuration: 1.0,
                suggestionsFrequency: .low,
                gestureComplexity: .medium,
                voiceControlPriority: .low,
                defaultViewMode: .organization
            )
        case .enthusiast:
            return InteractionPreferences(
                autoPlayEnabled: true,
                crossfadeDuration: 3.0,
                suggestionsFrequency: .medium,
                gestureComplexity: .high,
                voiceControlPriority: .medium,
                defaultViewMode: .detailed
            )
        case .social:
            return InteractionPreferences(
                autoPlayEnabled: true,
                crossfadeDuration: 1.5,
                suggestionsFrequency: .high,
                gestureComplexity: .medium,
                voiceControlPriority: .high,
                defaultViewMode: .sharing
            )
        case .ambient:
            return InteractionPreferences(
                autoPlayEnabled: true,
                crossfadeDuration: 4.0,
                suggestionsFrequency: .medium,
                gestureComplexity: .low,
                voiceControlPriority: .high,
                defaultViewMode: .minimal
            )
        case .analyzer:
            return InteractionPreferences(
                autoPlayEnabled: false,
                crossfadeDuration: 0.5,
                suggestionsFrequency: .low,
                gestureComplexity: .high,
                voiceControlPriority: .low,
                defaultViewMode: .technical
            )
        case .neutral:
            return InteractionPreferences(
                autoPlayEnabled: true,
                crossfadeDuration: 2.0,
                suggestionsFrequency: .medium,
                gestureComplexity: .medium,
                voiceControlPriority: .medium,
                defaultViewMode: .discovery
            )
        }
    }
}

/// Struct for UI-related preferences
struct UIPreferences {
    enum ListStyle {
        case list, grid, card, detailed, minimal
    }
    
    enum SortOrder {
        case alphabetical, recentlyPlayed, manual, recommended
    }
    
    enum FeaturedSectionSize {
        case none, small, medium, large
    }
    
    enum DetailLevel {
        case low, medium, high, maximum
    }
    
    enum NavigationStyle {
        case hierarchical, tabbed, contextual
    }
    
    let listStyle: ListStyle
    let showRecommendations: Bool
    let defaultSortOrder: SortOrder
    let featuredSectionSize: FeaturedSectionSize
    let detailLevel: DetailLevel
    let navigationStyle: NavigationStyle
}

/// Struct for interaction-related preferences
struct InteractionPreferences {
    enum FrequencyLevel {
        case low, medium, high
    }
    
    enum ComplexityLevel {
        case low, medium, high
    }
    
    enum PriorityLevel {
        case low, medium, high
    }
    
    enum ViewMode {
        case minimal, discovery, organization, detailed, sharing, technical
    }
    
    let autoPlayEnabled: Bool
    let crossfadeDuration: Double
    let suggestionsFrequency: FrequencyLevel
    let gestureComplexity: ComplexityLevel
    let voiceControlPriority: PriorityLevel
    let defaultViewMode: ViewMode
}

/// Engine for analyzing and adapting to user's music personality
final class PersonalityEngine: ObservableObject {
    // MARK: - Properties
    
    @Published private(set) var currentPersonality: PersonalityType = .explorer
    @Published private(set) var traits: [PersonalityTrait] = []
    
    private let aiLogger = AILogger.shared
    private var interactionHistory: [InteractionEvent] = []
    private var subscriptions = Set<AnyCancellable>()
    
    // Personality prediction thresholds
    private let minConfidenceThreshold: Float = MLConfig.Thresholds.minimumPersonalityMatchConfidence
    private let historyThreshold = 10 // Minimum interactions needed
    
    // MARK: - Initialization
    
    init() {
        setupObservers()
    }
    
    // MARK: - Public Interface
    
    func trackInteraction(_ type: InteractionType) {
        let event = InteractionEvent(type: type, timestamp: Date())
        interactionHistory.append(event)
        
        // Process after accumulating enough data
        if interactionHistory.count >= historyThreshold {
            analyzePersonality()
        }
    }
    
    func predictPersonality(from listeningHistory: [String: Any]) -> PersonalityPrediction {
        let prediction = analyzeListeningPatterns(listeningHistory)
        
        if prediction.confidence >= minConfidenceThreshold {
            updatePersonality(prediction.personality, confidence: prediction.confidence)
        }
        
        return prediction
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe mood changes
        NotificationCenter.default.publisher(for: .moodDidChange)
            .sink { [weak self] notification in
                if let mood = notification.object as? Mood {
                    self?.processMoodChange(mood)
                }
            }
            .store(in: &subscriptions)
        
        // Observe playlist modifications
        NotificationCenter.default.publisher(for: .playlistModified)
            .sink { [weak self] notification in
                self?.processPlaylistChange(notification.object as? MixTape)
            }
            .store(in: &subscriptions)
    }
    
    private func analyzePersonality() {
        let patterns = extractBehaviorPatterns()
        var scores = initializePersonalityScores()
        
        // Update scores based on behavior patterns
        patterns.forEach { pattern in
            switch pattern {
            case .frequentExploration:
                scores[.explorer] = (scores[.explorer] ?? 0) + 2
                scores[.enthusiast] = (scores[.enthusiast] ?? 0) + 1
                
            case .detailedOrganization:
                scores[.curator] = (scores[.curator] ?? 0) + 2
                scores[.analyzer] = (scores[.analyzer] ?? 0) + 1
                
            case .socialSharing:
                scores[.social] = (scores[.social] ?? 0) + 2
                scores[.explorer] = (scores[.explorer] ?? 0) + 1
                
            case .technicalAnalysis:
                scores[.analyzer] = (scores[.analyzer] ?? 0) + 2
                scores[.curator] = (scores[.curator] ?? 0) + 1
                
            case .backgroundListening:
                scores[.ambient] = (scores[.ambient] ?? 0) + 2
                
            case .intenseFocus:
                scores[.enthusiast] = (scores[.enthusiast] ?? 0) + 2
                scores[.analyzer] = (scores[.analyzer] ?? 0) + 1
            }
        }
        
        // Find dominant personality
        if let topPersonality = scores.max(by: { $0.value < $1.value })?.key {
            let confidence = calculateConfidence(scores: scores)
            updatePersonality(topPersonality, confidence: confidence)
        }
        
        // Clear old history
        pruneInteractionHistory()
    }
    
    private func extractBehaviorPatterns() -> Set<BehaviorPattern> {
        var patterns = Set<BehaviorPattern>()
        
        // Group interactions by type
        let groupedInteractions = Dictionary(grouping: interactionHistory) { $0.type }
        
        // Analyze exploration behavior
        if groupedInteractions[.newPlaylistCreated]?.count ?? 0 > 3 ||
           groupedInteractions[.genreExplored]?.count ?? 0 > 5 {
            patterns.insert(.frequentExploration)
        }
        
        // Analyze organization behavior
        if groupedInteractions[.playlistOrganized]?.count ?? 0 > 2 ||
           groupedInteractions[.tagsModified]?.count ?? 0 > 4 {
            patterns.insert(.detailedOrganization)
        }
        
        // Analyze social behavior
        if groupedInteractions[.playlistShared]?.count ?? 0 > 1 ||
           groupedInteractions[.collaborationJoined]?.count ?? 0 > 0 {
            patterns.insert(.socialSharing)
        }
        
        // Analyze technical interest
        if groupedInteractions[.audioAnalysisViewed]?.count ?? 0 > 2 ||
           groupedInteractions[.insightsViewed]?.count ?? 0 > 3 {
            patterns.insert(.technicalAnalysis)
        }
        
        // Analyze listening style
        let recentSessions = interactionHistory
            .filter { $0.type == .playbackStarted || $0.type == .playbackEnded }
            .sorted { $0.timestamp > $1.timestamp }
        
        if let averageSessionLength = calculateAverageSessionLength(from: recentSessions) {
            if averageSessionLength > 3600 { // More than 1 hour
                patterns.insert(.backgroundListening)
            }
            if averageSessionLength < 900 && recentSessions.count > 10 { // Less than 15 minutes but frequent
                patterns.insert(.intenseFocus)
            }
        }
        
        return patterns
    }
    
    private func initializePersonalityScores() -> [PersonalityType: Int] {
        Dictionary(uniqueKeysWithValues: PersonalityType.allCases.map { ($0, 0) })
    }
    
    private func calculateConfidence(scores: [PersonalityType: Int]) -> Float {
        guard let maxScore = scores.values.max(), maxScore > 0 else { return 0 }
        
        let totalScore = Float(scores.values.reduce(0, +))
        let dominantScore = Float(maxScore)
        
        return dominantScore / totalScore
    }
    
    private func updatePersonality(_ personality: PersonalityType, confidence: Float) {
        guard confidence >= minConfidenceThreshold else { return }
        
        let oldPersonality = currentPersonality
        currentPersonality = personality
        
        // Update traits based on personality
        traits = personality.defaultTraits
        
        // Log change
        aiLogger.logAccuracy(
            model: "PersonalityEngine",
            predictedValue: personality,
            actualValue: confidence > 0.8
        )
        
        // Notify observers
        NotificationCenter.default.post(
            name: .personalityDidChange,
            object: PersonalityChange(
                from: oldPersonality,
                to: personality,
                confidence: confidence
            )
        )
    }
    
    private func analyzeListeningPatterns(_ history: [String: Any]) -> PersonalityPrediction {
        // Extract features
        let features = extractListeningFeatures(from: history)
        
        // Make prediction
        let prediction = PersonalityPrediction(
            personality: predictFromFeatures(features),
            confidence: calculatePredictionConfidence(features)
        )
        
        // Log for analysis
        aiLogger.logInference(
            model: "PersonalityPrediction",
            duration: 0.1,
            success: prediction.confidence >= minConfidenceThreshold
        )
        
        return prediction
    }
    
    private func extractListeningFeatures(from history: [String: Any]) -> [String: Double] {
        var features: [String: Double] = [:]
        
        // Genre diversity
        if let genres = history["genres"] as? [String: Double] {
            features["genreDiversity"] = calculateDiversity(genres)
        }
        
        // Listening patterns
        if let timeOfDay = history["timeOfDay"] as? [String: Double] {
            features["timeVariability"] = calculateDiversity(timeOfDay)
        }
        
        // Tempo preferences
        if let tempo = history["tempo"] as? [String: Double] {
            features["tempoVariability"] = calculateDiversity(tempo)
        }
        
        return features
    }
    
    private func calculateDiversity(_ distribution: [String: Double]) -> Double {
        let total = distribution.values.reduce(0, +)
        guard total > 0 else { return 0 }
        
        // Calculate Shannon entropy
        return -distribution.values.reduce(0) { entropy, value in
            let p = value / total
            return entropy + (p * log2(p))
        }
    }
    
    private func predictFromFeatures(_ features: [String: Double]) -> PersonalityType {
        // Simple rule-based prediction (would use ML model in production)
        let genreDiversity = features["genreDiversity"] ?? 0
        let timeVariability = features["timeVariability"] ?? 0
        let tempoVariability = features["tempoVariability"] ?? 0
        
        if genreDiversity > 0.8 {
            return .explorer
        } else if timeVariability < 0.3 && tempoVariability < 0.3 {
            return .ambient
        } else if genreDiversity < 0.4 && tempoVariability > 0.7 {
            return .enthusiast
        } else {
            return .curator
        }
    }
    
    private func calculatePredictionConfidence(_ features: [String: Double]) -> Float {
        // Simple confidence calculation (would use ML model confidence in production)
        let featureValues = features.values
        let average = featureValues.reduce(0, +) / Double(featureValues.count)
        return Float(average)
    }
    
    private func processMoodChange(_ mood: Mood) {
        // Update personality traits based on mood patterns
        // Implementation would analyze mood transitions
    }
    
    private func processPlaylistChange(_ mixtape: MixTape?) {
        // Update personality traits based on playlist organization
        // Implementation would analyze playlist structure
    }
    
    private func calculateAverageSessionLength(from events: [InteractionEvent]) -> TimeInterval? {
        // Group start/end events into sessions
        // Return average session duration
        return nil // Placeholder
    }
    
    private func pruneInteractionHistory() {
        // Keep only recent history (last 30 days)
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
        interactionHistory = interactionHistory.filter { $0.timestamp > thirtyDaysAgo }
    }
}

// MARK: - Supporting Types

enum InteractionType {
    case newPlaylistCreated
    case playlistOrganized
    case genreExplored
    case tagsModified
    case playlistShared
    case collaborationJoined
    case audioAnalysisViewed
    case insightsViewed
    case playbackStarted
    case playbackEnded
}

struct InteractionEvent {
    let type: InteractionType
    let timestamp: Date
}

enum BehaviorPattern {
    case frequentExploration
    case detailedOrganization
    case socialSharing
    case technicalAnalysis
    case backgroundListening
    case intenseFocus
}

struct PersonalityPrediction {
    let personality: PersonalityType
    let confidence: Float
}

struct PersonalityChange {
    let from: PersonalityType
    let to: PersonalityType
    let confidence: Float
}

struct PersonalityTrait: Identifiable {
    let id = UUID()
    let name: String
    let strength: Float
}

// MARK: - Notification Names

extension Notification.Name {
    static let personalityDidChange = Notification.Name("personalityDidChange")
}

// MARK: - PersonalityType Extensions

extension PersonalityType {
    var defaultTraits: [PersonalityTrait] {
        switch self {
        case .explorer:
            return [
                PersonalityTrait(name: "Adventurous", strength: 0.9),
                PersonalityTrait(name: "Curious", strength: 0.8),
                PersonalityTrait(name: "Open-minded", strength: 0.7)
            ]
        case .curator:
            return [
                PersonalityTrait(name: "Organized", strength: 0.9),
                PersonalityTrait(name: "Methodical", strength: 0.8),
                PersonalityTrait(name: "Detail-oriented", strength: 0.7)
            ]
        case .enthusiast:
            return [
                PersonalityTrait(name: "Passionate", strength: 0.9),
                PersonalityTrait(name: "Dedicated", strength: 0.8),
                PersonalityTrait(name: "Knowledgeable", strength: 0.7)
            ]
        case .social:
            return [
                PersonalityTrait(name: "Collaborative", strength: 0.9),
                PersonalityTrait(name: "Sharing", strength: 0.8),
                PersonalityTrait(name: "Connected", strength: 0.7)
            ]
        case .ambient:
            return [
                PersonalityTrait(name: "Focused", strength: 0.9),
                PersonalityTrait(name: "Consistent", strength: 0.8),
                PersonalityTrait(name: "Balanced", strength: 0.7)
            ]
        case .analyzer:
            return [
                PersonalityTrait(name: "Analytical", strength: 0.9),
                PersonalityTrait(name: "Technical", strength: 0.8),
                PersonalityTrait(name: "Precise", strength: 0.7)
            ]
        }
    }
    
    var icon: String {
        switch self {
        case .explorer: return "safari"
        case .curator: return "folder"
        case .enthusiast: return "star"
        case .social: return "person.2"
        case .ambient: return "wave.3.right"
        case .analyzer: return "chart.bar"
        }
    }
    
    var themeColor: Color {
        switch self {
        case .explorer: return .blue
        case .curator: return .purple
        case .enthusiast: return .orange
        case .social: return .green
        case .ambient: return .teal
        case .analyzer: return .gray
        }
    }
    
    var description: String {
        switch self {
        case .explorer:
            return "You love discovering new music and exploring different genres. Always seeking fresh sounds and experiences."
        case .curator:
            return "You take pride in organizing and maintaining your music collection. Your playlists are carefully crafted."
        case .enthusiast:
            return "You're deeply passionate about music, with a thorough appreciation for artists and genres you love."
        case .social:
            return "Music is a way to connect with others for you. You enjoy sharing and collaborative playlist creation."
        case .ambient:
            return "You appreciate music as a backdrop to your activities, with consistent and focused listening patterns."
        case .analyzer:
            return "You're interested in the technical aspects of music, from production quality to compositional elements."
        }
    }
}

import Foundation
import CoreML
import Combine

class PersonalityEngine: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var currentPersonality: PersonalityType = .explorer
    @Published private(set) var traits: [PersonalityTrait] = []
    
    // MARK: - Private Properties
    
    private let aiLogger = AILogger.shared
    private var listeningHistory: [ListeningSession] = []
    private var genrePreferences: [String: Float] = [:]
    private var moodPatterns: [Mood: Int] = [:]
    private var interactionPatterns: [String: Int] = [:]
    
    private var personalitySubscriptions = Set<AnyCancellable>()
    
    // Analysis weights
    private let genreWeight: Float = 0.3
    private let moodWeight: Float = 0.3
    private let interactionWeight: Float = 0.4
    
    // MARK: - Initialization
    
    init() {
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    func updateFromListeningSession(_ session: ListeningSession) {
        listeningHistory.append(session)
        updateGenrePreferences(from: session)
        updateMoodPatterns(from: session)
        analyzePersonality()
    }
    
    func recordInteraction(_ type: InteractionType) {
        interactionPatterns[type.rawValue, default: 0] += 1
        
        // Only update personality after significant interaction changes
        if interactionPatterns[type.rawValue, default: 0] % 5 == 0 {
            analyzePersonality()
        }
    }
    
    func getTraitStrength(for trait: PersonalityTrait.TraitType) -> Float {
        traits.first { $0.type == trait }?.strength ?? 0.0
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe mood changes
        NotificationCenter.default
            .publisher(for: .moodDidChange)
            .sink { [weak self] notification in
                if let mood = notification.object as? Mood {
                    self?.moodPatterns[mood, default: 0] += 1
                    self?.analyzePersonality()
                }
            }
            .store(in: &personalitySubscriptions)
    }
    
    private func updateGenrePreferences(from session: ListeningSession) {
        session.songs.forEach { song in
            song.genres.forEach { genre in
                let weight = Float(song.playCount) / Float(session.totalPlayCount)
                genrePreferences[genre, default: 0] += weight
            }
        }
        
        // Normalize preferences
        let total = genrePreferences.values.reduce(0, +)
        genrePreferences = genrePreferences.mapValues { $0 / total }
    }
    
    private func updateMoodPatterns(from session: ListeningSession) {
        session.moodSequence.forEach { mood in
            moodPatterns[mood, default: 0] += 1
        }
    }
    
    private func analyzePersonality() {
        // Calculate trait scores
        var traitScores: [PersonalityTrait.TraitType: Float] = [:]
        
        // Analyze genre preferences
        let genreTraits = analyzeGenrePreferences()
        genreTraits.forEach { trait, score in
            traitScores[trait, default: 0] += score * genreWeight
        }
        
        // Analyze mood patterns
        let moodTraits = analyzeMoodPatterns()
        moodTraits.forEach { trait, score in
            traitScores[trait, default: 0] += score * moodWeight
        }
        
        // Analyze interaction patterns
        let interactionTraits = analyzeInteractionPatterns()
        interactionTraits.forEach { trait, score in
            traitScores[trait, default: 0] += score * interactionWeight
        }
        
        // Update traits
        traits = traitScores.map { trait, strength in
            PersonalityTrait(type: trait, strength: strength)
        }.sorted { $0.strength > $1.strength }
        
        // Determine dominant personality type
        let newPersonality = determinePersonalityType(from: traits)
        
        if newPersonality != currentPersonality {
            currentPersonality = newPersonality
            aiLogger.logUserInteraction(type: "personality_update",
                                      details: ["new_type": newPersonality.rawValue])
        }
    }
    
    private func analyzeGenrePreferences() -> [PersonalityTrait.TraitType: Float] {
        var traits: [PersonalityTrait.TraitType: Float] = [:]
        
        // Map genres to personality traits
        genrePreferences.forEach { genre, weight in
            switch genre.lowercased() {
            case "classical", "jazz", "ambient":
                traits[.analytical, default: 0] += weight
                traits[.reflective, default: 0] += weight
            case "rock", "metal", "punk":
                traits[.energetic, default: 0] += weight
                traits[.adventurous, default: 0] += weight
            case "electronic", "dance", "techno":
                traits[.experimental, default: 0] += weight
                traits[.energetic, default: 0] += weight
            case "folk", "acoustic", "singer-songwriter":
                traits[.empathetic, default: 0] += weight
                traits[.reflective, default: 0] += weight
            case "pop", "r&b":
                traits[.social, default: 0] += weight
                traits[.adaptable, default: 0] += weight
            default:
                break
            }
        }
        
        return traits
    }
    
    private func analyzeMoodPatterns() -> [PersonalityTrait.TraitType: Float] {
        var traits: [PersonalityTrait.TraitType: Float] = [:]
        let total = Float(moodPatterns.values.reduce(0, +))
        
        moodPatterns.forEach { mood, count in
            let weight = Float(count) / total
            switch mood {
            case .energetic:
                traits[.energetic] = weight
                traits[.adventurous] = weight * 0.7
            case .happy:
                traits[.social] = weight
                traits[.optimistic] = weight
            case .relaxed:
                traits[.reflective] = weight
                traits[.empathetic] = weight * 0.8
            case .focused:
                traits[.analytical] = weight
                traits[.disciplined] = weight
            case .melancholic:
                traits[.reflective] = weight
                traits[.empathetic] = weight
            case .neutral:
                traits[.adaptable] = weight
            }
        }
        
        return traits
    }
    
    private func analyzeInteractionPatterns() -> [PersonalityTrait.TraitType: Float] {
        var traits: [PersonalityTrait.TraitType: Float] = [:]
        let total = Float(interactionPatterns.values.reduce(0, +))
        
        interactionPatterns.forEach { type, count in
            let weight = Float(count) / total
            switch type {
            case InteractionType.skipTrack.rawValue:
                traits[.experimental] = weight
            case InteractionType.createPlaylist.rawValue:
                traits[.creative] = weight
            case InteractionType.shareMusic.rawValue:
                traits[.social] = weight
            case InteractionType.rateRecommendation.rawValue:
                traits[.analytical] = weight
            case InteractionType.adjustMoodSettings.rawValue:
                traits[.adaptable] = weight
            default:
                break
            }
        }
        
        return traits
    }
    
    private func determinePersonalityType(from traits: [PersonalityTrait]) -> PersonalityType {
        let dominantTraits = traits.prefix(3)
        
        // Map trait combinations to personality types
        if traits.containsAll([.experimental, .adventurous, .creative]) {
            return .explorer
        } else if traits.containsAll([.analytical, .disciplined, .reflective]) {
            return .architect
        } else if traits.containsAll([.social, .empathetic, .optimistic]) {
            return .harmonizer
        } else if traits.containsAll([.energetic, .adaptable, .creative]) {
            return .catalyst
        } else if traits.containsAll([.reflective, .empathetic, .analytical]) {
            return .sage
        }
        
        // Default to most common type if no clear match
        return .explorer
    }
}

// MARK: - Supporting Types

enum InteractionType: String {
    case skipTrack = "skip_track"
    case createPlaylist = "create_playlist"
    case shareMusic = "share_music"
    case rateRecommendation = "rate_recommendation"
    case adjustMoodSettings = "adjust_mood_settings"
}

struct PersonalityTrait: Identifiable {
    let id = UUID()
    let type: TraitType
    let strength: Float
    
    enum TraitType: String {
        case experimental
        case adventurous
        case creative
        case analytical
        case disciplined
        case reflective
        case social
        case empathetic
        case optimistic
        case energetic
        case adaptable
        
        var description: String {
            switch self {
            case .experimental: return "Open to new experiences"
            case .adventurous: return "Seeks excitement and variety"
            case .creative: return "Enjoys artistic expression"
            case .analytical: return "Thinks deeply and systematically"
            case .disciplined: return "Values structure and consistency"
            case .reflective: return "Contemplates meanings and patterns"
            case .social: return "Connects through shared experiences"
            case .empathetic: return "Understands others' emotions"
            case .optimistic: return "Maintains positive outlook"
            case .energetic: return "High energy and enthusiasm"
            case .adaptable: return "Flexible and accommodating"
            }
        }
    }
}

extension Array where Element == PersonalityTrait {
    func containsAll(_ traits: [PersonalityTrait.TraitType]) -> Bool {
        let types = self.map { $0.type }
        return traits.allSatisfy { types.contains($0) }
    }
}
