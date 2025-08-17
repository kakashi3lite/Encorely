//
//  AIMixtapesApp.swift
//  AI Mixtapes
//
//  Created by AI Assistant on 2024
//  Copyright © 2024 AI Mixtapes. All rights reserved.
//

import SwiftUI
import MusicKit

@main
struct AIMixtapesApp: App {
    // MARK: - Properties
    @StateObject private var appState = AppState()
    @StateObject private var musicAuthorizationManager = MusicAuthorizationManager()
    @StateObject private var mixtapeStore = MixtapeStore()
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(musicAuthorizationManager)
                .environmentObject(mixtapeStore)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    // MARK: - Private Methods
    private func setupApp() {
        // Configure app-wide settings
        configureAppearance()
        
        // Request music authorization
        Task {
            await musicAuthorizationManager.requestAuthorization()
        }
    }
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}