//
//  MainTabView.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import SwiftUI
import AVKit
import CoreData

struct MainTabView: View {
    @Environment(\.managedObjectContext) var moc
    @StateObject private var errorMonitor = CoreDataErrorMonitor()
    
    // Player state
    let queuePlayer: AVQueuePlayer
    let playerItemObserver: PlayerItemObserver
    let playerStatusObserver: PlayerStatusObserver
    @ObservedObject var currentPlayerItems: CurrentPlayerItems
    @ObservedObject var currentSongName: CurrentSongName
    @ObservedObject var isPlaying: IsPlaying
    var aiService: AIIntegrationService
    
    // Navigation and UI state
    @State private var selectedTab = AppSection.library
    @State private var navigationPath = NavigationPath()
    @State private var showMiniPlayer = true
    @State private var showingMoodPicker = false
    @State private var showingPersonalityView = false
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach([AppSection.library, .generate, .analyze, .insights, .settings], id: \.self) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("AI Mixtapes")
        } detail: {
            NavigationStack(path: $navigationPath) {
                Group {
                    switch selectedTab {
                    case .library:
                        LibraryView(aiService: aiService)
                    case .generate: 
                        AIGeneratedMixtapeView(moodEngine: aiService.moodEngine, personalityEngine: aiService.personalityEngine)
                    case .analyze:
                        AudioVisualizationView(queuePlayer: queuePlayer, 
                                             aiService: aiService,
                                             currentSongName: currentSongName)
                    case .insights:
                        InsightsDashboardView(aiService: aiService)
                    case .settings:
                        SettingsView(aiService: aiService)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        // Mood indicator/selector
                        Button(action: { showingMoodPicker = true }) {
                            Label(aiService.moodEngine.currentMood.rawValue,
                                  systemImage: aiService.moodEngine.currentMood.systemIcon)
                                .foregroundColor(aiService.moodEngine.currentMood.color)
                        }
                        
                        // Personality indicator/selector
                        Button(action: { showingPersonalityView = true }) {
                            Label(aiService.personalityEngine.currentPersonality.rawValue,
                                  systemImage: "person.crop.circle")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingMoodPicker) {
            MoodView(moodEngine: aiService.moodEngine)
        }
        .sheet(isPresented: $showingPersonalityView) {
            PersonalityView(personalityEngine: aiService.personalityEngine)
        }
        .overlay(alignment: .bottom) {
            if showMiniPlayer && currentSongName.wrappedValue != "Not Playing" {
                MiniPlayerView(
                    queuePlayer: queuePlayer,
                    currentSongName: currentSongName,
                    isPlaying: isPlaying,
                    showingFullPlayer: .constant(false),
                    aiService: aiService
                )
                .transition(.move(edge: .bottom))
            }
        }
        .environmentObject(aiService)
    }
}

/// App section enumeration for identifying tabs
enum AppSection: Hashable {
    case library
    case generate
    case analyze
    case insights
    case settings
    
    var title: String {
        switch self {
        case .library: return "Library"
        case .generate: return "Generate"
        case .analyze: return "Analyze"
        case .insights: return "Insights"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .library: return "music.note.list"
        case .generate: return "wand.and.stars"
        case .analyze: return "waveform"
        case .insights: return "chart.bar"
        case .settings: return "gear"
        }
    }
}
