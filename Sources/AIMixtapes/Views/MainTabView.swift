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
    
    // Mode selection state
    @State private var selectedMode = 0 // 0: Player, 1: Podcast, 2: News
    
    // Initializer
    init(
        queuePlayer: AVQueuePlayer,
        playerItemObserver: PlayerItemObserver,
        playerStatusObserver: PlayerStatusObserver,
        currentPlayerItems: CurrentPlayerItems,
        currentSongName: CurrentSongName,
        isPlaying: IsPlaying,
        aiService: AIIntegrationService
    ) {
        self.queuePlayer = queuePlayer
        self.playerItemObserver = playerItemObserver
        self.playerStatusObserver = playerStatusObserver
        self.currentPlayerItems = currentPlayerItems
        self.currentSongName = currentSongName
        self.isPlaying = isPlaying
        self.aiService = aiService
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Mode Selector at the top
                AnimatedModeSelector(selectedMode: $selectedMode, aiService: aiService)
                    .padding(.top, 8)
                
                // Mode-specific content
                ZStack {
                    // Player Mode Content
                    if selectedMode == 0 {
                        playerModeContent
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                    
                    // Podcast Mode Content
                    if selectedMode == 1 {
                        podcastModeContent
                            .transition(.opacity.combined(with: .move(edge: selectedMode > 1 ? .leading : .trailing)))
                    }
                    
                    // News Mode Content
                    if selectedMode == 2 {
                        newsModeContent
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedMode)
                
                Spacer()
                
                // Bottom TabView for navigation within each mode
                TabView(selection: $selectedTab) {
                    // Library Tab with NavigationStack
                    NavigationStack(path: $navigationPath) {
                        EmptyView() // Content is displayed in the main view area based on mode
                    }
                    .tabItem {
                        Label("Library", systemImage: "music.note.list")
                            .environment(\.symbolVariants, selectedTab == 0 ? .fill : .none)
                    }
                    .tag(0)
                
                    // AI Generate Tab
                    EmptyView() // Content is displayed in the main view area based on mode
                    .tabItem {
                        Label("Generate", systemImage: "wand.and.stars")
                            .environment(\.symbolVariants, selectedTab == 1 ? .fill : .none)
                    }
                    .tag(1)
                
                    EmptyView() // Content is displayed in the main view area based on mode
                        .tabItem {
                            Label("Analyze", systemImage: "waveform")
                                .environment(\.symbolVariants, selectedTab == 2 ? .fill : .none)
                        }
                        .tag(2)
                
                    EmptyView() // Content is displayed in the main view area based on mode
                        .tabItem {
                            Label("Insights", systemImage: "chart.bar")
                                .environment(\.symbolVariants, selectedTab == 3 ? .fill : .none)
                        }
                        .tag(3)
                
                    EmptyView() // Content is displayed in the main view area based on mode
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                                .environment(\.symbolVariants, selectedTab == 4 ? .fill : .none)
                        }
                        .tag(4)
                }
            }
            .tint(aiService.moodEngine.currentMood.color)

            // AI Suggestion Banner
            AISuggestionBanner(
                isVisible: .constant(true),
                aiService: aiService,
                tabSelection: $selectedTab
            )
            .padding(.bottom, 60)
        }
        .onChange(of: shouldNavigateToMixtape) { navigate in
            if navigate, let mixtape = newlyCreatedMixtape {
                selectedTab = 0
                selectedMode = 0 // Ensure we're in Player mode
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    navigationPath.append(mixtape)
                    shouldNavigateToMixtape = false
                    newlyCreatedMixtape = nil
                }
            }
        }
        .onChange(of: selectedMode) { newMode in
            // Provide haptic feedback when changing modes
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            
            // Track mode change
            aiService.trackInteraction(type: "mode_changed_to_\(modeTitle(for: newMode))")
        }
        .onChange(of: selectedTab) { newTab in
            // Track tab change
            aiService.trackInteraction(type: "tab_changed_to_\(newTab)")
        }
    }
    
    // MARK: - Mode-specific Views
    
    /// Player Mode Content
    private var playerModeContent: some View {
        VStack {
            // Library content with navigation
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
        }
    }
    
    /// Podcast Mode Content
    private var podcastModeContent: some View {
        VStack {
            // Podcast content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Featured podcasts header
                    HStack {
                        Text("Featured Podcasts")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button("See All") {}
                            .foregroundColor(aiService.moodEngine.currentMood.color)
                    }
                    .padding(.horizontal)
                    
                    // Featured podcasts carousel
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(0..<5) { i in
                                PodcastCard(
                                    title: ["Tech Insights", "Music Theory", "AI Revolution", "Sound Stories", "Beat Lab"][i],
                                    host: ["Sarah Chen", "Mark Johnson", "AI Collective", "Emma Davis", "Rhythm Crew"][i],
                                    coverImage: "podcast\(i+1)",
                                    mood: aiService.moodEngine.currentMood
                                )
                                .frame(width: 160, height: 220)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Recent episodes section
                    Text("Recent Episodes")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.top, 10)
                    
                    // Episodes list
                    VStack(spacing: 12) {
                        ForEach(0..<6) { i in
                            PodcastEpisodeRow(
                                title: ["The Future of AI Music", "Composing with Algorithms", "Exploring Sound Design", 
                                        "Interview with Music Producers", "Neural Audio Processing", "Creative AI Tools"][i],
                                podcast: ["Tech Insights", "Music Theory", "Sound Stories", 
                                          "Beat Lab", "AI Revolution", "Music Theory"][i % 5],
                                duration: [45, 32, 58, 41, 37, 29][i],
                                aiService: aiService
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
    }
    
    /// News Mode Content
    private var newsModeContent: some View {
        VStack {
            // News content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Trending header
                    HStack {
                        Text("Music News")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button("Refresh") {}
                            .foregroundColor(aiService.moodEngine.currentMood.color)
                    }
                    .padding(.horizontal)
                    
                    // Featured news card
                    VStack(alignment: .leading, spacing: 10) {
                        ZStack(alignment: .bottomLeading) {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 200)
                                .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TRENDING")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(aiService.moodEngine.currentMood.color)
                                
                                Text("AI Revolutionizes Music Production in 2025")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("How artificial intelligence is transforming the way artists create and produce music")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(2)
                            }
                            .padding()
                        }
                    }
                    .padding(.horizontal)
                    
                    // Latest news section
                    Text("Latest Updates")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    // News list
                    VStack(spacing: 15) {
                        ForEach(0..<5) { i in
                            NewsArticleRow(
                                title: ["New AI Music Generation Plugin Released", 
                                        "Virtual Reality Concert Platform Launches", 
                                        "Streaming Services Introduce Spatial Audio Feature",
                                        "Indie Artists Embrace AI Collaboration Tools",
                                        "Music Industry Report: AI Impact on Creativity"][i],
                                source: ["TechCrunch", "Music Business Weekly", "AudioPro", "IndieWire", "Industry Analysis"][i],
                                timeAgo: [2, 5, 8, 12, 24][i],
                                hasImage: [true, false, true, false, true][i],
                                aiService: aiService
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
    }
    
    /// Title for mode
    private func modeTitle(for index: Int) -> String {
        ["player", "podcast", "news"][index]
    }
    
    /// Handle mixtape creation and navigation
    private func handleMixtapeCreated(_ mixtape: MixTape) {
        newlyCreatedMixtape = mixtape
        shouldNavigateToMixtape = true
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
        let currentMood = aiService.moodEngine.currentMood
        let personality = aiService.personalityEngine.currentPersonality
        let timeOfDay = Calendar.current.component(.hour, from: Date())
        
        // Dynamic suggestions based on time and context
        var suggestions: [AISuggestion] = []
        
        // Morning suggestions (6 AM - 12 PM)
        if timeOfDay >= 6 && timeOfDay < 12 {
            suggestions.append(AISuggestion(
                title: "Morning Energy Mix",
                message: "Start your day with an energizing \(currentMood.rawValue) playlist",
                icon: "sunrise.fill",
                color: .orange,
                action: .createMixtape(currentMood),
                actionTitle: "Create Mix"
            ))
        }
        
        // Work hours suggestions (9 AM - 5 PM)
        if timeOfDay >= 9 && timeOfDay < 17 {
            suggestions.append(AISuggestion(
                title: "Focus Enhancement",
                message: "Generate a concentration-boosting playlist based on your work patterns",
                icon: "brain.head.profile",
                color: .blue,
                action: .navigateToTab(1),
                actionTitle: "Enhance Focus"
            ))
        }
        
        // Evening suggestions (5 PM - 11 PM)
        if timeOfDay >= 17 && timeOfDay < 23 {
            suggestions.append(AISuggestion(
                title: "Evening Unwinding",
                message: "Create a relaxing mix to match your evening mood",
                icon: "moon.stars.fill",
                color: .purple,
                action: .createMixtape(.relaxed),
                actionTitle: "Unwind"
            ))
        }
        
        // Personality-based suggestions
        switch personality {
        case .explorer:
            suggestions.append(AISuggestion(
                title: "Discover New Sounds",
                message: "Let AI find fresh tracks that match your adventurous taste",
                icon: "compass.fill",
                color: .green,
                action: .navigateToTab(1),
                actionTitle: "Explore"
            ))
        case .curator:
            suggestions.append(AISuggestion(
                title: "Organize Your Collection",
                message: "Use AI to optimize your playlist organization",
                icon: "square.stack.3d.up.fill",
                color: .indigo,
                action: .navigateToTab(3),
                actionTitle: "Optimize"
            ))
        default:
            suggestions.append(contentsOf: defaultSuggestions(mood: currentMood))
        }
        
        // Pick most relevant suggestion
        self.suggestion = selectMostRelevantSuggestion(from: suggestions)
        aiService.trackInteraction(type: "ai_suggestion_shown")
    }
    
    private func selectMostRelevantSuggestion(from suggestions: [AISuggestion]) -> AISuggestion? {
        // Prioritize suggestions based on user's recent interactions
        // For now, return random but in future could use more sophisticated selection
        return suggestions.randomElement()
    }
    
    private func defaultSuggestions(mood: Mood) -> [AISuggestion] {
        [
            AISuggestion(
                title: "Mood-Matched Mix",
                message: "Create a playlist that matches your \(mood.rawValue.lowercased()) mood",
                icon: mood.systemIcon,
                color: mood.color,
                action: .createMixtape(mood),
                actionTitle: "Create Now"
            )
        ]
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
