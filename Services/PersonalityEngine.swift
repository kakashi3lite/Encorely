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

/// Enum representing different user personality types for UI/UX adaptation
enum PersonalityType: String, CaseIterable {
    case explorer = "Explorer"   // Values discovery and variety
    case curator = "Curator"     // Values organization and quality
    case enthusiast = "Enthusiast" // Values deep dives and expertise
    case social = "Social"       // Values sharing and connecting
    case ambient = "Ambient"     // Values background/passive use
    case analyzer = "Analyzer"   // Values technical details and control
    
    /// Returns a theme color associated with each personality type
    var themeColor: Color {
        switch self {
        case .explorer: return Color.blue
        case .curator: return Color.purple
        case .enthusiast: return Color.orange
        case .social: return Color.green
        case .ambient: return Color.teal
        case .analyzer: return Color.gray
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

/// Engine responsible for analyzing user behavior to determine personality type
class PersonalityEngine: ObservableObject {
    @Published var currentPersonality: PersonalityType = .curator
    
    // Personality traits (range from 0.0 to 1.0)
    private var explorerTrait: Float = 0.0
    private var curatorTrait: Float = 0.5 // Default slightly higher
    private var enthusiastTrait: Float = 0.0
    private var socialTrait: Float = 0.0
    private var ambientTrait: Float = 0.0
    private var analyzerTrait: Float = 0.0
    
    // Tracking interaction patterns
    private var interactionHistory: [InteractionEvent] = []
    private var interactionPatterns: [String: Int] = [:]
    
    // Subscription for tracking updates
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load saved personality if available
        loadSavedPersonality()
        
        // Set up timer to periodically analyze user behavior
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.analyzePersonalityTraits()
            }
            .store(in: &cancellables)
    }
    
    /// Process an interaction event to analyze user behavior
    func processInteraction(_ event: InteractionEvent) {
        // Store the event
        interactionHistory.append(event)
        
        // Limit history size
        if interactionHistory.count > 200 {
            interactionHistory.removeFirst(interactionHistory.count - 200)
        }
        
        // Update interaction pattern counts
        if interactionPatterns[event.type] != nil {
            interactionPatterns[event.type]! += 1
        } else {
            interactionPatterns[event.type] = 1
        }
        
        // Update personality traits based on the interaction
        updatePersonalityTraits(forEvent: event)
        
        // Check if we should re-analyze personality
        if interactionHistory.count % 10 == 0 {
            analyzePersonalityTraits()
        }
    }
    
    /// Update personality traits based on a specific interaction
    private func updatePersonalityTraits(forEvent event: InteractionEvent) {
        let smallImpact: Float = 0.01
        let mediumImpact: Float = 0.03
        let largeImpact: Float = 0.05
        
        // Analyze event type and update relevant traits
        switch event.type {
        case "create_mixtape":
            curatorTrait += mediumImpact
            
        case "edit_mixtape_order":
            curatorTrait += mediumImpact
            
        case "play_mixtape":
            // Basic play doesn't strongly indicate any trait
            break
            
        case "skip_song":
            if getSkipFrequency() > 0.5 {
                explorerTrait += smallImpact
                curatorTrait -= smallImpact
            }
            
        case "replay_song":
            enthusiastTrait += mediumImpact
            
        case "share_mixtape":
            socialTrait += largeImpact
            
        case "background_play":
            ambientTrait += mediumImpact
            
        case "view_song_details":
            analyzerTrait += smallImpact
            enthusiastTrait += smallImpact
            
        case "use_equalizer":
            analyzerTrait += largeImpact
            
        case "search":
            explorerTrait += smallImpact
            
        case "create_playlist_from_recommendations":
            explorerTrait += mediumImpact
            
        case "select_discovery_recommendation":
            explorerTrait += mediumImpact
            
        case "organize_collections":
            curatorTrait += largeImpact
            
        case "add_metadata":
            curatorTrait += mediumImpact
            analyzerTrait += smallImpact
            
        case "deep_dive_artist":
            enthusiastTrait += largeImpact
            
        case "repeat_album":
            enthusiastTrait += mediumImpact
            
        case "share_to_social":
            socialTrait += largeImpact
            
        case "collaborative_playlist":
            socialTrait += largeImpact
            
        case "ambient_mode":
            ambientTrait += largeImpact
            
        case "technical_settings":
            analyzerTrait += largeImpact
            
        default:
            // For unrecognized events, make small updates based on the name
            if event.type.contains("explore") || event.type.contains("discover") {
                explorerTrait += smallImpact
            } else if event.type.contains("organize") || event.type.contains("sort") {
                curatorTrait += smallImpact
            } else if event.type.contains("detail") || event.type.contains("focus") {
                enthusiastTrait += smallImpact
            } else if event.type.contains("share") || event.type.contains("social") {
                socialTrait += smallImpact
            } else if event.type.contains("background") || event.type.contains("ambient") {
                ambientTrait += smallImpact
            } else if event.type.contains("technical") || event.type.contains("advanced") {
                analyzerTrait += smallImpact
            }
        }
        
        // Normalize traits to keep them in 0.0-1.0 range
        normalizeTraits()
    }
    
    /// Analyze personality traits and determine dominant personality type
    private func analyzePersonalityTraits() {
        // Find the dominant trait
        let traits: [PersonalityType: Float] = [
            .explorer: explorerTrait,
            .curator: curatorTrait,
            .enthusiast: enthusiastTrait,
            .social: socialTrait,
            .ambient: ambientTrait,
            .analyzer: analyzerTrait
        ]
        
        if let dominantTrait = traits.max(by: { $0.value < $1.value }) {
            // Only update if there's a significant change
            if dominantTrait.key != currentPersonality && dominantTrait.value > 0.3 {
                currentPersonality = dominantTrait.key
                saveCurrentPersonality()
            }
        }
    }
    
    /// Calculate how often the user skips songs
    private func getSkipFrequency() -> Float {
        let skipCount = interactionPatterns["skip_song"] ?? 0
        let playCount = interactionPatterns["play_mixtape"] ?? 1 // Avoid division by zero
        
        return Float(skipCount) / Float(playCount)
    }
    
    /// Normalize all traits to ensure they stay in the 0.0-1.0 range
    private func normalizeTraits() {
        // Ensure all traits are within bounds
        explorerTrait = min(1.0, max(0.0, explorerTrait))
        curatorTrait = min(1.0, max(0.0, curatorTrait))
        enthusiastTrait = min(1.0, max(0.0, enthusiastTrait))
        socialTrait = min(1.0, max(0.0, socialTrait))
        ambientTrait = min(1.0, max(0.0, ambientTrait))
        analyzerTrait = min(1.0, max(0.0, analyzerTrait))
        
        // Optional: Scale all traits so they sum to a fixed value
        let sum = explorerTrait + curatorTrait + enthusiastTrait + socialTrait + ambientTrait + analyzerTrait
        if sum > 0 {
            let scale = 3.0 / sum // Scale so they sum to 3.0 (allows multiple strong traits)
            explorerTrait *= scale
            curatorTrait *= scale
            enthusiastTrait *= scale
            socialTrait *= scale
            ambientTrait *= scale
            analyzerTrait *= scale
        }
    }
    
    /// Manually set a personality type (for user overrides)
    func setPersonalityType(_ type: PersonalityType) {
        currentPersonality = type
        
        // Reset all traits
        explorerTrait = 0.0
        curatorTrait = 0.0
        enthusiastTrait = 0.0
        socialTrait = 0.0
        ambientTrait = 0.0
        analyzerTrait = 0.0
        
        // Set the selected trait to a high value
        switch type {
        case .explorer: explorerTrait = 0.8
        case .curator: curatorTrait = 0.8
        case .enthusiast: enthusiastTrait = 0.8
        case .social: socialTrait = 0.8
        case .ambient: ambientTrait = 0.8
        case .analyzer: analyzerTrait = 0.8
        }
        
        saveCurrentPersonality()
    }
    
    /// Load saved personality from UserDefaults
    private func loadSavedPersonality() {
        if let savedString = UserDefaults.standard.string(forKey: "userPersonality"),
           let savedPersonality = PersonalityType(rawValue: savedString) {
            currentPersonality = savedPersonality
        }
    }
    
    /// Save current personality to UserDefaults
    private func saveCurrentPersonality() {
        UserDefaults.standard.set(currentPersonality.rawValue, forKey: "userPersonality")
    }
    
    /// Get all personality traits with their current values
    func getPersonalityTraits() -> [(type: PersonalityType, value: Float)] {
        return [
            (.explorer, explorerTrait),
            (.curator, curatorTrait),
            (.enthusiast, enthusiastTrait),
            (.social, socialTrait),
            (.ambient, ambientTrait),
            (.analyzer, analyzerTrait)
        ]
    }
}
