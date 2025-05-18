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

/// Main tab view controller with enhanced navigation
struct MainTabView: View {
    @Environment(\.managedObjectContext) var moc
    
    // Player state
    let queuePlayer: AVQueuePlayer
    let playerItemObserver: PlayerItemObserver
    let playerStatusObserver: PlayerStatusObserver
    @ObservedObject var currentPlayerItems: CurrentPlayerItems
    @ObservedObject var currentSongName: CurrentSongName
    @ObservedObject var isPlaying: IsPlaying
    var aiService: AIIntegrationService
    
    // Navigation state
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var newlyCreatedMixtape: MixTape?
    @State private var shouldNavigateToMixtape = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Library Tab with NavigationStack
            NavigationStack(path: $navigationPath) {
                ContentView(
                    queuePlayer: queuePlayer,
                    playerItemObserver: playerItemObserver,
                    playerStatusObserver: playerStatusObserver,
                    currentPlayerItems: currentPlayerItems,
                    currentSongName: currentSongName,
                    isPlaying: isPlaying,
                    aiService: aiService
                )
                .navigationDestination(for: MixTape.self) { mixtape in
                    MixTapeView(
                        songs: mixtape.songsArray,
                        mixTape: mixtape,
                        currentMixTapeName: .constant(""),
                        currentMixTapeImage: .constant(URL(fileURLWithPath: "")),
                        queuePlayer: queuePlayer,
                        currentStatusObserver: playerStatusObserver,
                        currentItemObserver: playerItemObserver,
                        currentPlayerItems: currentPlayerItems,
                        currentSongName: currentSongName,
                        isPlaying: isPlaying,
                        aiService: aiService
                    )
                }
            }
            .environment(\.managedObjectContext, moc)
            .tabItem { Label("Library", systemImage: "music.note.list") }
            .tag(0)
            
            // AI Generate Tab with completion callback
            AIGeneratedMixtapeViewWrapper(
                aiService: aiService,
                onMixtapeCreated: handleMixtapeCreated
            )
            .environment(\.managedObjectContext, moc)
            .tabItem { Label("Generate", systemImage: "wand.and.stars") }
            .tag(1)
            
            AudioVisualizationView(queuePlayer: queuePlayer, aiService: aiService, currentSongName: currentSongName)
                .tabItem { Label("Analyze", systemImage: "waveform") }
                .tag(2)
            
            InsightsDashboardView(aiService: aiService)
                .environment(\.managedObjectContext, moc)
                .tabItem { Label("Insights", systemImage: "chart.bar") }
                .tag(3)
            
            SettingsView(aiService: aiService)
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(4)
        }
        .onChange(of: shouldNavigateToMixtape) { navigate in
            if navigate, let mixtape = newlyCreatedMixtape {
                selectedTab = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigationPath.append(mixtape)
                    shouldNavigateToMixtape = false
                    newlyCreatedMixtape = nil
                }
            }
        }
    }
    
    /// Handle mixtape creation and navigation
    private func handleMixtapeCreated(_ mixtape: MixTape) {
        newlyCreatedMixtape = mixtape
        shouldNavigateToMixtape = true
    }
}

/// Wrapper for AIGeneratedMixtapeView with completion handling
struct AIGeneratedMixtapeViewWrapper: View {
    let aiService: AIIntegrationService
    let onMixtapeCreated: (MixTape) -> Void
    @Environment(\.managedObjectContext) var moc
    
    var body: some View {
        AIGeneratedMixtapeView(aiService: aiService)
            .onReceive(NotificationCenter.default.publisher(for: .mixtapeCreated)) { notification in
                if let mixtape = notification.object as? MixTape {
                    onMixtapeCreated(mixtape)
                }
            }
    }
}

/// Notification extension for mixtape creation
extension Notification.Name {
    static let mixtapeCreated = Notification.Name("mixtapeCreated")
}

/// Color blending extension
extension Color {
    func blended(with color: Color) -> Color {
        // In a real app, we would implement color blending
        // For now, just return the original color
        return self
    }
}

/// AI suggestion banner that appears periodically
struct AISuggestionBanner: View {
    @Binding var isVisible: Bool
    var aiService: AIIntegrationService
    @Binding var tabSelection: Int
    
    // State
    @State private var suggestion: AISuggestion?
    @State private var dismissTimer: Timer?
    
    var body: some View {
        Group {
            if let suggestion = suggestion {
                VStack {
                    HStack(spacing: 16) {
                        // Icon
                        Image(systemName: suggestion.icon)
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(suggestion.color))
                        
                        // Content
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(suggestion.message)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        // Dismiss button
                        Button(action: {
                            dismissSuggestion()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                    
                    // Action button
                    if let action = suggestion.action {
                        Button(action: {
                            executeAction(action)
                        }) {
                            Text(suggestion.actionTitle ?? "Try Now")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(suggestion.color))
                        }
                        .padding(.top, -16)
                        .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal)
                .transition(.move(edge: .bottom))
            }
        }
        .onAppear {
            // Generate a suggestion
            generateSuggestion()
            
            // Set up a timer to periodically show suggestions
            setupSuggestionTimer()
        }
        .onDisappear {
            // Cancel timer
            dismissTimer?.invalidate()
        }
    }
    
    /// Generate a context-aware suggestion
    private func generateSuggestion() {
        // In a real app, this would be based on user context, time of day, etc.
        // For now, we'll use some examples
        
        let currentMood = aiService.moodEngine.currentMood
        let personality = aiService.personalityEngine.currentPersonality
        
        // Possible suggestions
        let suggestions = [
            AISuggestion(
                title: "Create a \(currentMood.rawValue) Mixtape",
                message: "Generate a mixtape that matches your current \(currentMood.rawValue.lowercased()) mood.",
                icon: currentMood.systemIcon,
                color: currentMood.color,
                action: .navigateToTab(1),
                actionTitle: "Create Now"
            ),
            AISuggestion(
                title: "Analyze Your Music",
                message: "Discover the audio features and mood patterns in your current song.",
                icon: "waveform.path.ecg",
                color: .orange,
                action: .navigateToTab(2),
                actionTitle: "Analyze"
            ),
            AISuggestion(
                title: "Check Your Insights",
                message: "See how your listening habits have changed this week.",
                icon: "chart.bar",
                color: .green,
                action: .navigateToTab(3),
                actionTitle: "View Insights"
            ),
            AISuggestion(
                title: "Voice Commands Available",
                message: "Try saying 'Hey Siri, play a \(currentMood.rawValue.lowercased()) playlist'",
                icon: "waveform.and.mic",
                color: .blue,
                action: nil,
                actionTitle: nil
            )
        ]
        
        // Pick a random suggestion
        self.suggestion = suggestions.randomElement()
        
        // Track impression
        aiService.trackInteraction(type: "ai_suggestion_shown")
    }
    
    /// Set up a timer to periodically show suggestions
    private func setupSuggestionTimer() {
        // Cancel existing timer
        dismissTimer?.invalidate()
        
        // Auto-dismiss after 10 seconds
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            withAnimation {
                isVisible = false
            }
        }
    }
    
    /// Dismiss the current suggestion
    private func dismissSuggestion() {
        withAnimation {
            isVisible = false
        }
        
        // Track dismissal
        aiService.trackInteraction(type: "ai_suggestion_dismissed")
    }
    
    /// Execute a suggestion action
    private func executeAction(_ action: SuggestionAction) {
        switch action {
        case .navigateToTab(let tabIndex):
            tabSelection = tabIndex
            
        case .openSheet(let sheetType):
            // In a real app, we would handle different sheet types
            print("Open sheet: \(sheetType)")
            
        case .createMixtape(let mood):
            // Navigate to generator and set mood
            tabSelection = 1
            
            // In a real app, we would set the mood in the generator
            print("Create mixtape for mood: \(mood.rawValue)")
        }
        
        // Dismiss the suggestion
        dismissSuggestion()
        
        // Track action taken
        aiService.trackInteraction(type: "ai_suggestion_action_taken")
    }
}

/// Model for AI suggestions
struct AISuggestion {
    let title: String
    let message: String
    let icon: String
    let color: Color
    let action: SuggestionAction?
    let actionTitle: String?
}

/// Actions that can be taken from a suggestion
enum SuggestionAction {
    case navigateToTab(Int)
    case openSheet(String)
    case createMixtape(Mood)
}

/// Settings view for configuring AI features
struct SettingsView: View {
    var aiService: AIIntegrationService
    
    // State for settings
    @State private var useAudioAnalysis = true
    @State private var useFacialExpressions = false
    @State private var useSiriIntegration = true
    @State private var showPersonalitySettings = false
    @State private var showMoodSettings = false
    @State private var showSiriSettings = false
    
    var body: some View {
        NavigationView {
            Form {
                // AI Features section
                Section(header: Text("AI Features")) {
                    Toggle("Audio Analysis", isOn: $useAudioAnalysis)
                    Toggle("Facial Expression Detection", isOn: $useFacialExpressions)
                    Toggle("Siri Integration", isOn: $useSiriIntegration)
                }
                
                // Personality section
                Section(header: Text("Personality Profile")) {
                    Button(action: {
                        showPersonalitySettings = true
                    }) {
                        HStack {
                            Text("Your Music Personality")
                            Spacer()
                            Text(aiService.personalityEngine.currentPersonality.rawValue)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .sheet(isPresented: $showPersonalitySettings) {
                        PersonalityView(personalityEngine: aiService.personalityEngine)
                    }
                }
                
                // Mood section
                Section(header: Text("Mood Settings")) {
                    Button(action: {
                        showMoodSettings = true
                    }) {
                        HStack {
                            Text("Current Mood")
                            Spacer()
                            Text(aiService.moodEngine.currentMood.rawValue)
                                .foregroundColor(aiService.moodEngine.currentMood.color)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .sheet(isPresented: $showMoodSettings) {
                        MoodView(moodEngine: aiService.moodEngine)
                    }
                }
                
                // Siri section
                Section(header: Text("Siri Integration")) {
                    Button(action: {
                        showSiriSettings = true
                    }) {
                        HStack {
                            Text("Manage Siri Shortcuts")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .sheet(isPresented: $showSiriSettings) {
                        SiriShortcutsView(aiService: aiService)
                    }
                }
                
                // About section
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("Swanand Tanavade")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationBarTitle("Settings", displayMode: .large)
            .onChange(of: useAudioAnalysis) { newValue in
                // Track setting change
                aiService.trackInteraction(type: "setting_audio_analysis_\(newValue ? "enabled" : "disabled")")
            }
            .onChange(of: useFacialExpressions) { newValue in
                // Track setting change
                aiService.trackInteraction(type: "setting_facial_expressions_\(newValue ? "enabled" : "disabled")")
            }
            .onChange(of: useSiriIntegration) { newValue in
                // Track setting change
                aiService.trackInteraction(type: "setting_siri_integration_\(newValue ? "enabled" : "disabled")")
            }
        }
    }
}
