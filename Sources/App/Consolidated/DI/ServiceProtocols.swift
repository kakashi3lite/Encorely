//
//  ServiceProtocols.swift
//  AI-Mixtapes
//
//  Created by Claude AI on 05/30/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import AVFoundation
import CoreData
import Domain

// MARK: - Service Protocols

/// Protocol for AI service coordination
public protocol AIServiceCoordinating: AnyObject {
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
    func delete<T: NSManagedObject>(_ object: T) throws
}

/// Protocol for cache management
public protocol CacheManaging: AnyObject {
    func store<T: Codable>(_ object: T, forKey key: String)
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
