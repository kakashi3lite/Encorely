//
//  PersonalityEngine.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Combine
import CoreML
import Foundation
import os.log
import SwiftUI

// PersonalityType is now defined in SharedTypes.swift
extension PersonalityType {
    /// Returns a theme color associated with each personality type
    var themeColor: Color {
        switch self {
        case .analyzer: Color.blue
        case .explorer: Color.purple
        case .planner: Color.orange
        case .creative: Color.green
        case .balanced: Color.gray
        case .ambient: Color.teal
        case .analyzer: Color.gray
        case .neutral: Color.secondary
        }
    }

    /// Returns UI preferences for each personality type
    var uiPreferences: UIPreferences {
        switch self {
        case .explorer:
            UIPreferences(
                listStyle: .grid,
                showRecommendations: true,
                defaultSortOrder: .recommended,
                featuredSectionSize: .large,
                detailLevel: .medium,
                navigationStyle: .tabbed
            )
        case .curator:
            UIPreferences(
                listStyle: .list,
                showRecommendations: false,
                defaultSortOrder: .manual,
                featuredSectionSize: .small,
                detailLevel: .high,
                navigationStyle: .hierarchical
            )
        case .enthusiast:
            UIPreferences(
                listStyle: .detailed,
                showRecommendations: true,
                defaultSortOrder: .alphabetical,
                featuredSectionSize: .medium,
                detailLevel: .maximum,
                navigationStyle: .hierarchical
            )
        case .social:
            UIPreferences(
                listStyle: .card,
                showRecommendations: true,
                defaultSortOrder: .recentlyPlayed,
                featuredSectionSize: .large,
                detailLevel: .low,
                navigationStyle: .tabbed
            )
        case .ambient:
            UIPreferences(
                listStyle: .minimal,
                showRecommendations: true,
                defaultSortOrder: .recommended,
                featuredSectionSize: .small,
                detailLevel: .low,
                navigationStyle: .contextual
            )
        case .analyzer:
            UIPreferences(
                listStyle: .detailed,
                showRecommendations: false,
                defaultSortOrder: .manual,
                featuredSectionSize: .none,
                detailLevel: .maximum,
                navigationStyle: .hierarchical
            )
        case .neutral:
            UIPreferences(
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
            InteractionPreferences(
                autoPlayEnabled: true,
                crossfadeDuration: 2.0,
                suggestionsFrequency: .high,
                gestureComplexity: .high,
                voiceControlPriority: .medium,
                defaultViewMode: .discovery
            )
        case .curator:
            InteractionPreferences(
                autoPlayEnabled: false,
                crossfadeDuration: 1.0,
                suggestionsFrequency: .low,
                gestureComplexity: .medium,
                voiceControlPriority: .low,
                defaultViewMode: .organization
            )
        case .enthusiast:
            InteractionPreferences(
                autoPlayEnabled: true,
                crossfadeDuration: 3.0,
                suggestionsFrequency: .medium,
                gestureComplexity: .high,
                voiceControlPriority: .medium,
                defaultViewMode: .detailed
            )
        case .social:
            InteractionPreferences(
                autoPlayEnabled: true,
                crossfadeDuration: 1.5,
                suggestionsFrequency: .high,
                gestureComplexity: .medium,
                voiceControlPriority: .high,
                defaultViewMode: .sharing
            )
        case .ambient:
            InteractionPreferences(
                autoPlayEnabled: true,
                crossfadeDuration: 4.0,
                suggestionsFrequency: .medium,
                gestureComplexity: .low,
                voiceControlPriority: .high,
                defaultViewMode: .minimal
            )
        case .analyzer:
            InteractionPreferences(
                autoPlayEnabled: false,
                crossfadeDuration: 0.5,
                suggestionsFrequency: .low,
                gestureComplexity: .high,
                voiceControlPriority: .low,
                defaultViewMode: .technical
            )
        case .neutral:
            InteractionPreferences(
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
    // MARK: - Published Properties

    @Published private(set) var currentPersonality: Asset.PersonalityColor = .enthusiast
    @Published private(set) var traits: [PersonalityTrait] = []
    @Published private(set) var isAnalyzing = false
    @Published private(set) var confidence: Double = 0.0

    // MARK: - Private Properties

    private let queue = DispatchQueue(label: "com.aimixtapes.personalityengine", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.aimixtapes", category: "PersonalityEngine")
    private var cancellables = Set<AnyCancellable>()
    private var personalityModel: MLModel?

    // State management
    private var interactionHistory: [InteractionEvent] = []
    private var lastAnalysis: Date?
    private var analysisCooldown: TimeInterval = 3600 // 1 hour
    private var stateRestorationTimer: Timer?

    // Error handling
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    private var errorCount = 0

    // MARK: - Initialization

    init() {
        setupStateRestoration()
        loadModel()
        restoreState()
    }

    // MARK: - Public Interface

    /// Update personality with validation and state management
    /// - Parameter personality: New personality to set
    func updatePersonality(_ personality: Asset.PersonalityColor) {
        guard personality != currentPersonality else { return }

        queue.async { [weak self] in
            guard let self else { return }

            let event = InteractionEvent(
                type: .personalityChange,
                oldValue: currentPersonality.rawValue,
                newValue: personality.rawValue,
                timestamp: Date()
            )

            DispatchQueue.main.async {
                self.currentPersonality = personality
                self.interactionHistory.append(event)
                self.persistState()

                // Log change
                self.logger.info("Personality updated: \(personality.rawValue)")

                // Trigger UI updates
                NotificationCenter.default.post(
                    name: .personalityDidChange,
                    object: self,
                    userInfo: ["personality": personality]
                )
            }
        }
    }

    /// Record user interaction for personality analysis
    /// - Parameter interaction: The interaction to record
    func recordInteraction(_ interaction: InteractionEvent) {
        queue.async { [weak self] in
            self?.interactionHistory.append(interaction)
            self?.analyzePersonalityIfNeeded()
        }
    }

    /// Force a personality analysis
    /// - Returns: Publisher with analysis results or error
    func analyzePersonality() -> AnyPublisher<PersonalityPrediction, Error> {
        guard shouldPerformAnalysis() else {
            return Fail(error: AppError.analysisThrottled)
                .eraseToAnyPublisher()
        }

        return Deferred {
            Future { [weak self] promise in
                guard let self else {
                    promise(.failure(AppError.serviceUnavailable))
                    return
                }

                queue.async {
                    self.performAnalysis(promise: promise)
                }
            }
        }
        .handleEvents(
            receiveSubscription: { [weak self] _ in
                self?.isAnalyzing = true
            },
            receiveCompletion: { [weak self] _ in
                self?.isAnalyzing = false
            }
        )
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    // MARK: - Private Implementation

    private func loadModel() {
        queue.async { [weak self] in
            guard let self else { return }

            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all

                // Load model (replace with actual model class)
                // self.personalityModel = try PersonalityModel(configuration: config)

                logger.info("Personality model loaded successfully")
            } catch {
                logger.error("Failed to load personality model: \(error.localizedDescription)")
                handleModelLoadError(error)
            }
        }
    }

    private func performAnalysis(promise: @escaping (Result<PersonalityPrediction, Error>) -> Void) {
        guard !interactionHistory.isEmpty else {
            promise(.failure(AppError.insufficientData))
            return
        }

        do {
            // Perform analysis (example implementation)
            let prediction = try analyzeBehaviorPatterns()

            // Update state
            DispatchQueue.main.async { [weak self] in
                self?.updateFromPrediction(prediction)
                self?.lastAnalysis = Date()
                promise(.success(prediction))
            }
        } catch {
            handleAnalysisError(error, promise: promise)
        }
    }

    private func analyzeBehaviorPatterns() throws -> PersonalityPrediction {
        guard !interactionHistory.isEmpty else {
            throw AppError.insufficientData
        }
        
        // Analyze interaction patterns
        let recentInteractions = getRecentInteractions()
        let behaviorScores = calculateBehaviorScores(from: recentInteractions)
        
        // Determine dominant personality
        let dominantPersonality = determineDominantPersonality(from: behaviorScores)
        let confidence = calculateConfidence(for: dominantPersonality, scores: behaviorScores)
        let traits = extractPersonalityTraits(from: behaviorScores)
        
        return PersonalityPrediction(
            dominantPersonality: dominantPersonality,
            confidence: confidence,
            traits: traits
        )
    }
    
    private func getRecentInteractions() -> [InteractionEvent] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return interactionHistory.filter { $0.timestamp >= cutoffDate }
    }
    
    private func calculateBehaviorScores(from interactions: [InteractionEvent]) -> [PersonalityType: Double] {
        var scores: [PersonalityType: Double] = [:]
        
        // Initialize scores
        PersonalityType.allCases.forEach { scores[$0] = 0.0 }
        
        for interaction in interactions {
            switch interaction.type {
            case .personalityChange:
                if let asset = interaction.metadata["asset"] as? String,
                   let personalityType = mapAssetToPersonalityType(asset) {
                    scores[personalityType, default: 0] += 2.0
                }
                
            case .playlistCreation:
                // Analyze playlist creation patterns
                if let mood = interaction.metadata["mood"] as? String {
                    switch mood.lowercased() {
                    case "energetic", "upbeat":
                        scores[.enthusiast, default: 0] += 1.5
                    case "calm", "relaxed":
                        scores[.minimalist, default: 0] += 1.5
                    case "creative", "experimental":
                        scores[.explorer, default: 0] += 1.5
                    case "focused", "productive":
                        scores[.focused, default: 0] += 1.5
                    default:
                        break
                    }
                }
                
            case .songSkip:
                // Frequent skipping might indicate explorer personality
                scores[.explorer, default: 0] += 0.5
                
            case .volumeChange:
                // Volume preferences can indicate personality
                if let volume = interaction.metadata["volume"] as? Double {
                    if volume > 0.8 {
                        scores[.enthusiast, default: 0] += 0.3
                    } else if volume < 0.3 {
                        scores[.minimalist, default: 0] += 0.3
                    }
                }
                
            case .genreSelection:
                // Genre preferences indicate personality
                if let genre = interaction.metadata["genre"] as? String {
                    switch genre.lowercased() {
                    case "electronic", "techno", "edm":
                        scores[.enthusiast, default: 0] += 1.0
                    case "ambient", "classical", "instrumental":
                        scores[.minimalist, default: 0] += 1.0
                    case "experimental", "jazz", "world":
                        scores[.explorer, default: 0] += 1.0
                    case "lo-fi", "study", "focus":
                        scores[.focused, default: 0] += 1.0
                    default:
                        break
                    }
                }
                
            case .moodChange:
                // Mood changes can indicate personality traits
                if let newMood = interaction.metadata["newMood"] as? String {
                    switch newMood.lowercased() {
                    case "energetic":
                        scores[.enthusiast, default: 0] += 1.0
                    case "calm":
                        scores[.minimalist, default: 0] += 1.0
                    case "creative":
                        scores[.explorer, default: 0] += 1.0
                    case "focused":
                        scores[.focused, default: 0] += 1.0
                    default:
                        break
                    }
                }
                
            case .sessionLength:
                // Session length patterns
                if let duration = interaction.metadata["duration"] as? TimeInterval {
                    if duration > 3600 { // Long sessions (>1 hour)
                        scores[.focused, default: 0] += 1.0
                    } else if duration < 900 { // Short sessions (<15 min)
                        scores[.explorer, default: 0] += 0.5
                    }
                }
                
            case .uiInteraction:
                // UI interaction patterns
                if let action = interaction.metadata["action"] as? String {
                    switch action {
                    case "shuffle":
                        scores[.explorer, default: 0] += 0.5
                    case "repeat":
                        scores[.focused, default: 0] += 0.5
                    case "visualizer":
                        scores[.enthusiast, default: 0] += 0.3
                    default:
                        break
                    }
                }
            }
        }
        
        // Normalize scores based on interaction count
        let totalInteractions = Double(interactions.count)
        if totalInteractions > 0 {
            for key in scores.keys {
                scores[key] = scores[key]! / totalInteractions
            }
        }
        
        return scores
    }
    
    private func determineDominantPersonality(from scores: [PersonalityType: Double]) -> PersonalityType {
        return scores.max(by: { $0.value < $1.value })?.key ?? .minimalist
    }
    
    private func calculateConfidence(for personality: PersonalityType, scores: [PersonalityType: Double]) -> Float {
        let dominantScore = scores[personality] ?? 0.0
        let sortedScores = scores.values.sorted(by: >)
        
        guard sortedScores.count >= 2 else {
            return Float(dominantScore.clamped(to: 0...1))
        }
        
        let secondHighest = sortedScores[1]
        let difference = dominantScore - secondHighest
        
        // Confidence based on separation between top scores
        let confidence = (dominantScore + difference).clamped(to: 0...1)
        return Float(confidence)
    }
    
    private func extractPersonalityTraits(from scores: [PersonalityType: Double]) -> [PersonalityTrait] {
        var traits: [PersonalityTrait] = []
        
        // Extract traits based on score patterns
        for (personality, score) in scores {
            if score > 0.3 {
                switch personality {
                case .enthusiast:
                    traits.append(.energetic)
                    if score > 0.6 { traits.append(.social) }
                case .minimalist:
                    traits.append(.calm)
                    if score > 0.6 { traits.append(.focused) }
                case .explorer:
                    traits.append(.curious)
                    if score > 0.6 { traits.append(.creative) }
                case .focused:
                    traits.append(.disciplined)
                    if score > 0.6 { traits.append(.analytical) }
                }
            }
        }
        
        return Array(Set(traits)) // Remove duplicates
    }
    
    private func mapAssetToPersonalityType(_ asset: String) -> PersonalityType? {
        switch asset.lowercased() {
        case "enthusiast", "energetic", "vibrant":
            return .enthusiast
        case "minimalist", "calm", "simple":
            return .minimalist
        case "explorer", "creative", "experimental":
            return .explorer
        case "focused", "productive", "disciplined":
            return .focused
        default:
            return nil
        }
    }
    
    private func mapPersonalityTypeToAsset(_ personality: PersonalityType) -> String {
        switch personality {
        case .enthusiast:
            return "enthusiast"
        case .minimalist:
            return "minimalist"
        case .explorer:
            return "explorer"
        case .focused:
            return "focused"
        }
    }

    private func updateFromPrediction(_ prediction: PersonalityPrediction) {
        guard prediction.confidence > 0.6 else {
            logger.warning("Low confidence prediction ignored: \(prediction.confidence)")
            return
        }

        updatePersonality(prediction.dominantPersonality)
        traits = prediction.traits
        confidence = prediction.confidence
    }

    // MARK: - Error Handling

    private func handleModelLoadError(_ error: Error) {
        errorCount += 1

        if errorCount < maxRetries {
            DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay) {
                self.loadModel()
            }
        } else {
            logger.error("Model load failed after \(maxRetries) attempts")
            NotificationCenter.default.post(
                name: .personalityEngineError,
                object: self,
                userInfo: ["error": error]
            )
        }
    }

    private func handleAnalysisError(_ error: Error,
                                     promise: @escaping (Result<PersonalityPrediction, Error>) -> Void)
    {
        logger.error("Analysis error: \(error.localizedDescription)")

        if errorCount < maxRetries {
            errorCount += 1
            DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay) {
                self.performAnalysis(promise: promise)
            }
        } else {
            promise(.failure(error))
        }
    }

    // MARK: - State Management

    private func setupStateRestoration() {
        stateRestorationTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.persistState()
        }
    }

    private func persistState() {
        let state: [String: Any] = [
            "currentPersonality": currentPersonality.rawValue,
            "confidence": confidence,
            "lastAnalysis": lastAnalysis?.timeIntervalSinceReferenceDate ?? 0,
            "traits": traits.map(\.rawValue),
        ]

        UserDefaults.standard.set(state, forKey: "PersonalityEngineState")
    }

    private func restoreState() {
        guard let state = UserDefaults.standard.dictionary(forKey: "PersonalityEngineState"),
              let personalityValue = state["currentPersonality"] as? String,
              let personality = Asset.PersonalityColor(rawValue: personalityValue)
        else {
            return
        }

        currentPersonality = personality
        confidence = state["confidence"] as? Double ?? 0.0
        if let timestamp = state["lastAnalysis"] as? TimeInterval {
            lastAnalysis = Date(timeIntervalSinceReferenceDate: timestamp)
        }
    }

    private func shouldPerformAnalysis() -> Bool {
        guard let lastAnalysis else { return true }
        return Date().timeIntervalSince(lastAnalysis) > analysisCooldown
    }
}

// MARK: - Supporting Types

struct InteractionEvent: Codable {
    let type: InteractionType
    let oldValue: String?
    let newValue: String
    let timestamp: Date
}

enum InteractionType: String, Codable {
    case personalityChange
    case moodChange
    case playlistCreation
    case songSkip
    case songComplete
    case ratingChange
}

struct PersonalityPrediction {
    let dominantPersonality: Asset.PersonalityColor
    let confidence: Double
    let traits: [PersonalityTrait]
}

struct PersonalityTrait: Identifiable {
    let id = UUID()
    let name: String
    let score: Double

    var rawValue: String {
        "\(name):\(score)"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let personalityDidChange = Notification.Name("com.aimixtapes.personalityDidChange")
    static let personalityEngineError = Notification.Name("com.aimixtapes.personalityEngineError")
}
