//
//  ContentView.swift
//  AI Mixtapes
//
//  Created by AI Assistant on 2024
//  Copyright © 2024 AI Mixtapes. All rights reserved.
//

import SwiftUI
import MusicKit

struct ContentView: View {
    // MARK: - Environment Objects
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var musicAuthorizationManager: MusicAuthorizationManager
    @EnvironmentObject private var mixtapeStore: MixtapeStore
    
    // MARK: - State
    @State private var selectedTab: Tab = .discover
    
    // MARK: - Body
    var body: some View {
        Group {
            if musicAuthorizationManager.isAuthorized {
                mainTabView
            } else {
                musicAuthorizationView
            }
        }
        .onAppear {
            checkMusicAuthorization()
        }
    }
    
    // MARK: - Views
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .tabItem {
                    Image(systemName: "music.note")
                    Text("Discover")
                }
                .tag(Tab.discover)
            
            MixtapesView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("My Mixtapes")
                }
                .tag(Tab.mixtapes)
            
            GenerateView()
                .tabItem {
                    Image(systemName: "wand.and.stars")
                    Text("Generate")
                }
                .tag(Tab.generate)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(Tab.profile)
        }
        .accentColor(.primary)
    }
    
    private var musicAuthorizationView: some View {
        MusicAuthorizationView()
    }
    
    // MARK: - Private Methods
    private func checkMusicAuthorization() {
        Task {
            await musicAuthorizationManager.checkAuthorizationStatus()
        }
    }
}

// MARK: - Tab Enum
enum Tab: String, CaseIterable {
    case discover = "discover"
    case mixtapes = "mixtapes"
    case generate = "generate"
    case profile = "profile"
    
    var title: String {
        switch self {
        case .discover:
            return "Discover"
        case .mixtapes:
            return "My Mixtapes"
        case .generate:
            return "Generate"
        case .profile:
            return "Profile"
        }
    }
    
    var systemImage: String {
        switch self {
        case .discover:
            return "music.note"
        case .mixtapes:
            return "list.bullet"
        case .generate:
            return "wand.and.stars"
        case .profile:
            return "person.circle"
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(MusicAuthorizationManager())
        .environmentObject(MixtapeStore())
}