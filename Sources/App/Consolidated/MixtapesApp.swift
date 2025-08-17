//
//  MixtapesApp.swift
//  AI-Mixtapes
//
//  Created by Claude AI on 05/30/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import AVFoundation
import CoreData
import Resolver
import SwiftUI

@main
struct MixtapesApp: App {
    let persistenceController = PersistenceController.shared
    
    // Initialize required components
    private let player = AVQueuePlayer()
    private let currentPlayerItems = CurrentPlayerItems()
    private let currentSongName = CurrentSongName()
    private let isPlaying = IsPlaying()
    
    init() {
        // Initialize dependency injection container
        DIContainer.setup()
    }

    var body: some Scene {
        WindowGroup {
            let aiService = Resolver.resolve(AIServiceCoordinating.self) as! AIIntegrationService
            ContentView(
                queuePlayer: player,
                playerItemObserver: PlayerItemObserver(),
                playerStatusObserver: PlayerStatusObserver(),
                currentPlayerItems: currentPlayerItems,
                currentSongName: currentSongName,
                isPlaying: isPlaying,
                aiService: aiService
            )
            .environment(\EnvironmentValues.managedObjectContext, persistenceController.container.viewContext)
            .environmentObject(Resolver.aiService)
        }
    }
}
