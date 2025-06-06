//
//  MixtapesApp.swift
//  AI-Mixtapes
//
//  Created by Claude AI on 05/30/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import SwiftUI
import Resolver

@main
struct MixtapesApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        // Initialize dependency injection container
        DIContainer.setup()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(Resolver.resolve(AIServiceCoordinating.self) as! AIIntegrationService)
        }
    }
}
