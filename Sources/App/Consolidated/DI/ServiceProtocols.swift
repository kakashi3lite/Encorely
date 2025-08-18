//
//  ServiceProtocols.swift
//  AI-Mixtapes
//
//  Created by Claude AI on 05/30/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import AVFoundation
import CoreData
import Foundation
import SwiftUI

// MARK: - Type Definitions

public enum PersonalityType: String, Codable, CaseIterable {
    case analyzer = "Analyzer"
    case explorer = "Explorer"
    case curator = "Curator"
    case enthusiast = "Enthusiast"
    case social = "Social"
    case ambient = "Ambient"
    case balanced = "Balanced"
}

public enum AppError: LocalizedError {
    case audioLoadFailed(Error)
    case deletionFailure(Error)
    case saveFailure(Error)
    case aiServiceUnavailable
    case resourcesUnavailable
    case serviceUnavailable
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case let .audioLoadFailed(error):
            "Failed to load audio: \(error.localizedDescription)"
        case let .deletionFailure(error):
            "Failed to delete item: \(error.localizedDescription)"
        case let .saveFailure(error):
            "Failed to save changes: \(error.localizedDescription)"
        case .aiServiceUnavailable:
            "AI service is temporarily unavailable"
        case .resourcesUnavailable:
            "Required resources are not available"
        case .serviceUnavailable:
            "Service is temporarily unavailable"
        case let .unknown(error):
            "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

// MARK: - Placeholder Types (to be defined elsewhere)

// Core Data type aliases - Song and MixTape defined in Domain module
public typealias Playlist = NSManagedObject
public typealias PlaylistContext = String
public typealias MoodAction = String
public typealias PersonalityTrait = String
public typealias AppTheme = String
public typealias NotificationEvent = String
public typealias SheetType = String

// MARK: - Service Protocols

/// Protocol for AI service coordination
public protocol AIServiceCoordinating: AnyObject, ObservableObject {
    var moodEngine: MoodDetecting { get }
    var personalityEngine: PersonalityAnalyzing { get }
    var recommendationEngine: RecommendationProviding { get }
    func trackInteraction(type: String, mixtape: MixTape?)
}

/// Protocol for mood detection capabilities
public protocol MoodDetecting: AnyObject {
    var currentMood: Mood { get }
    var moodConfidence: Float { get }
    func setMood(_ mood: Mood, confidence: Float)
    func detectMoodFromCurrentAudio(player: AVQueuePlayer)
    func getMoodBasedRecommendations() -> [MixTape]
    func getMoodBasedActions() -> [MoodAction]
}

/// Protocol for personality analysis
public protocol PersonalityAnalyzing: AnyObject {
    var currentPersonality: PersonalityType { get }
    func setPersonalityType(_ type: PersonalityType)
    func getPersonalityTraits() -> [PersonalityTrait]
}

/// Protocol for recommendation services
public protocol RecommendationProviding: AnyObject {
    func getPersonalizedRecommendations() -> [MixTape]
    func getSuggestedMixtapeTitles() -> [String]
    func getRecommendationsForMood(_ mood: Mood) -> [MixTape]
}

/// Protocol for audio analysis
public protocol AudioAnalyzing: AnyObject {
    func startRealTimeAnalysis(completion: @escaping (AudioFeatures) -> Void) throws
    func stopRealTimeAnalysis()
    func extractFeatures(from url: URL) async throws -> AudioFeatures
}

/// Protocol for audio processing
public protocol AudioProcessing: AnyObject {
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) -> [Float]
    func extractSpectralFeatures(_ buffer: AVAudioPCMBuffer) -> AudioFeatures
}

/// Protocol for playlist generation
public protocol PlaylistGenerating: AnyObject {
    func generatePlaylist(from songs: [Song], context: PlaylistContext, maxSongs: Int) -> Playlist
}

/// Protocol for voice command handling
public protocol VoiceCommandHandling: AnyObject {
    func handlePlayMoodIntent(_ mood: String) -> Bool
    func handleCreateMixtapeIntent(for activity: String) -> Bool
    func donateShortcut(for action: String, mood: String)
}

/// Protocol for theme management
public protocol ThemeProviding: AnyObject {
    func getThemeForPersonality(_ personality: PersonalityType) -> AppTheme
    func getThemeForMood(_ mood: Mood) -> AppTheme
}

/// Protocol for notification handling
public protocol NotificationHandling: AnyObject {
    func scheduleNotification(for event: NotificationEvent)
    func requestPermissions() async -> Bool
}

/// Protocol for error coordination
public protocol ErrorCoordinating: AnyObject {
    func handle(_ error: AppError)
    var currentError: AppError? { get }
    var showingError: Bool { get set }
}

/// Protocol for navigation coordination
public protocol NavigationCoordinating: AnyObject {
    func navigateToTab(_ tab: Int)
    func presentSheet(_ sheet: SheetType)
    func dismissSheet()
}

/// Protocol for analytics tracking
public protocol AnalyticsTracking: AnyObject {
    func track(event: String, parameters: [String: Any]?)
    func trackError(_ error: Error, context: String)
}

/// Protocol for data management
public protocol DataManaging: AnyObject {
    func save() throws
    func fetch<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate?) throws -> [T]
    func delete(_ object: some NSManagedObject) throws
}

/// Protocol for cache management
public protocol CacheManaging: AnyObject {
    func store(_ object: some Codable, forKey key: String)
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) -> T?
    func remove(forKey key: String)
}

// MARK: - Error Handling Protocols

public protocol AudioErrorHandling: AnyObject {
    func handleAudioLoadError(_ error: Error) -> AppError
    func handleAudioProcessingError(_ error: Error) -> AppError
}

public protocol AIErrorHandling: AnyObject {
    func handleModelLoadError(_ error: Error) -> AppError
    func handleInferenceError(_ error: Error) -> AppError
}

public protocol NetworkErrorHandling: AnyObject {
    func handleNetworkError(_ error: Error) -> AppError
    func handleTimeoutError() -> AppError
}
