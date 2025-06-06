//
//  DIContainer.swift
//  AI-Mixtapes
//
//  Created by Claude AI on 05/30/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import Resolver
import CoreData
import AVFoundation
import Domain

/// Dependency Injection Container for AI-Mixtapes app
/// Configures all service dependencies using Resolver
public final class DIContainer {
    
    /// Configure all dependencies at app launch
    public static func setup() {
        setupCoreServices()
        setupAIServices()
        setupAudioServices()
        setupUIServices()
        setupErrorHandling()
        setupDataServices()
    }
    
    // MARK: - Core Services
    
    private static func setupCoreServices() {
        // Error handling
        Resolver.register { ErrorCoordinator.shared }
            .implements(ErrorCoordinating.self)
            .scope(.application)
        
        // Navigation coordination
        Resolver.register { AppCoordinator() }
            .implements(NavigationCoordinating.self)
            .scope(.application)
        
        // Analytics and tracking
        Resolver.register { AnalyticsService() }
            .implements(AnalyticsTracking.self)
            .scope(.application)
    }
    
    // MARK: - AI Services
    
    private static func setupAIServices() {
        // Mood Engine
        Resolver.register { MoodEngine() }
            .implements(MoodDetecting.self)
            .scope(.application)
        
        // Personality Engine
        Resolver.register { PersonalityEngine() }
            .implements(PersonalityAnalyzing.self)
            .scope(.application)
        
        // Recommendation Engine
        Resolver.register { 
            RecommendationEngine(
                moodEngine: Resolver.resolve(MoodDetecting.self),
                personalityEngine: Resolver.resolve(PersonalityAnalyzing.self)
            )
        }
        .implements(RecommendationProviding.self)
        .scope(.application)
        
        // AI Integration Service (Main coordinator)
        Resolver.register {
            let context = Resolver.resolve(NSManagedObjectContext.self)
            return AIIntegrationService(context: context)
        }
        .implements(AIServiceCoordinating.self)
        .scope(.application)
    }
    
    // MARK: - Audio Services
    
    private static func setupAudioServices() {
        // Audio Analysis Service
        Resolver.register { AudioAnalysisService() }
            .implements(AudioAnalyzing.self)
            .scope(.application)
        
        // Audio Processor
        Resolver.register { AudioProcessor() }
            .implements(AudioProcessing.self)
            .scope(.application)
        
        // Playlist Generator
        Resolver.register {
            ContextBasedPlaylistGenerator(
                audioAnalysisService: Resolver.resolve(AudioAnalyzing.self),
                moodEngine: Resolver.resolve(MoodDetecting.self)
            )
        }
        .implements(PlaylistGenerating.self)
        .scope(.application)
    }
    
    // MARK: - UI Services
    
    private static func setupUIServices() {
        // Siri Integration Service
        Resolver.register { SiriIntegrationService() }
            .implements(VoiceCommandHandling.self)
            .scope(.application)
        
        // Theme Manager
        Resolver.register { ThemeManager() }
            .implements(ThemeProviding.self)
            .scope(.application)
        
        // Notification Manager
        Resolver.register { NotificationManager() }
            .implements(NotificationHandling.self)
            .scope(.application)
    }
    
    // MARK: - Error Handling
    
    private static func setupErrorHandling() {
        // Audio Error Handler
        Resolver.register { AudioErrorHandler() }
            .implements(AudioErrorHandling.self)
            .scope(.application)
        
        // AI Error Handler
        Resolver.register { AIErrorHandler() }
            .implements(AIErrorHandling.self)
            .scope(.application)
        
        // Network Error Handler
        Resolver.register { NetworkErrorHandler() }
            .implements(NetworkErrorHandling.self)
            .scope(.application)
    }
    
    // MARK: - Data Services
    
    private static func setupDataServices() {
        // Core Data Context
        Resolver.register { PersistenceController.shared.container.viewContext }
            .implements(NSManagedObjectContext.self)
            .scope(.application)
        
        // Data Manager
        Resolver.register {
            DataManager(context: Resolver.resolve(NSManagedObjectContext.self))
        }
        .implements(DataManaging.self)
        .scope(.application)
        
        // Cache Manager
        Resolver.register { CacheManager() }
            .implements(CacheManaging.self)
            .scope(.application)
    }
}

// MARK: - Resolver Extensions

public extension Resolver {
    /// Convenience method for resolving AI Integration Service
    static var aiService: AIServiceCoordinating {
        resolve(AIServiceCoordinating.self)
    }
    
    /// Convenience method for resolving Error Coordinator
    static var errorCoordinator: ErrorCoordinating {
        resolve(ErrorCoordinating.self)
    }
    
    /// Convenience method for resolving Navigation Coordinator
    static var navigationCoordinator: NavigationCoordinating {
        resolve(NavigationCoordinating.self)
    }
}
