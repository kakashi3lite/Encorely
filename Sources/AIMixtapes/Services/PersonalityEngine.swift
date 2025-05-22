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
import os.log

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
            guard let self = self else { return }
            
            let event = InteractionEvent(
                type: .personalityChange,
                oldValue: self.currentPersonality.rawValue,
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
                guard let self = self else {
                    promise(.failure(AppError.serviceUnavailable))
                    return
                }
                
                self.queue.async {
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
            guard let self = self else { return }
            
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all
                
                // Load model (replace with actual model class)
                // self.personalityModel = try PersonalityModel(configuration: config)
                
                self.logger.info("Personality model loaded successfully")
            } catch {
                self.logger.error("Failed to load personality model: \(error.localizedDescription)")
                self.handleModelLoadError(error)
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
        // Implement actual analysis logic
        // This is a placeholder implementation
        return PersonalityPrediction(
            dominantPersonality: .enthusiast,
            confidence: 0.8,
            traits: []
        )
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
    
    private func handleAnalysisError(_ error: Error, promise: @escaping (Result<PersonalityPrediction, Error>) -> Void) {
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
            "traits": traits.map { $0.rawValue }
        ]
        
        UserDefaults.standard.set(state, forKey: "PersonalityEngineState")
    }
    
    private func restoreState() {
        guard let state = UserDefaults.standard.dictionary(forKey: "PersonalityEngineState"),
              let personalityValue = state["currentPersonality"] as? String,
              let personality = Asset.PersonalityColor(rawValue: personalityValue) else {
            return
        }
        
        currentPersonality = personality
        confidence = state["confidence"] as? Double ?? 0.0
        if let timestamp = state["lastAnalysis"] as? TimeInterval {
            lastAnalysis = Date(timeIntervalSinceReferenceDate: timestamp)
        }
    }
    
    private func shouldPerformAnalysis() -> Bool {
        guard let lastAnalysis = lastAnalysis else { return true }
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
