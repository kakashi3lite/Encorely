//
//  ContentView.swift
//  Mixtapes
//
//  Created by Swanand Tanavade on 03/25/23.
//  Updated by Claude AI on 05/16/25.
//

import SwiftUI
import CoreData
import AVKit

struct ContentView: View {
    // Core environment and state
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: MixTape.entity(), sortDescriptors: [
        NSSortDescriptor(keyPath: \MixTape.lastPlayedDate, ascending: false)
    ]) var mixTapes: FetchedResults<MixTape>
    
    // State for sheets and views
    @State private var showingDocsPicker: Bool = false
    @State private var showingNowPlayingSheet: Bool = false
    @State private var showingMoodSelector: Bool = false
    @State private var showingPersonalityView: Bool = false
    @State private var showingOnboarding: Bool = false
    
    // Player state
    @State var currentMixTapeImage: URL = URL.init(fileURLWithPath: "")
    @State var currentMixTapeName: String = ""
    let queuePlayer: AVQueuePlayer
    let playerItemObserver: PlayerItemObserver
    let playerStatusObserver: PlayerStatusObserver
    @ObservedObject var currentPlayerItems: CurrentPlayerItems
    @ObservedObject var currentSongName: CurrentSongName
    @ObservedObject var isPlaying: IsPlaying
    
    // AI services
    @ObservedObject var aiService: AIIntegrationService
    
    var body: some View {
        moodAwareBody
    }
    
    // MARK: - Mood-Aware Body Implementation
    
    var moodAwareBody: some View {
        ZStack {
            VStack(spacing: 0) {
                // AI insights banner
                AIInsightsView(aiService: aiService)
                    .padding(.vertical, 8)
                
                // Personalized message banner
                PersonalizedMessageBanner(aiService: aiService)
                    .padding(.bottom, 8)
                
                NavigationView {
                    VStack(spacing: 0) {
                        // Mood-aware recommendations section (if applicable)
                        if aiService.moodEngine.moodConfidence > 0.6 {
                            moodRecommendationsSection
                        }
                        
                        // Adaptive list based on personality & mood
                        adaptiveListContent
                    }
                    .navigationBarTitle("Mixtapes")
                    .navigationBarItems(
                        leading: Button(action: {
                            self.showingPersonalityView.toggle()
                            aiService.trackInteraction(type: "open_personality_view")
                        }) {
                            Image(systemName: "person.crop.circle")
                                .imageScale(.large)
                                .foregroundColor(aiService.personalityEngine.currentPersonality.themeColor)
                        }
                        .sheet(isPresented: $showingPersonalityView) {
                            PersonalityView(personalityEngine: aiService.personalityEngine)
                        },
                        trailing:
                            HStack {
                                Button(action: {
                                    showingMoodSelector.toggle()
                                    aiService.trackInteraction(type: "open_mood_selector")
                                }) {
                                    Image(systemName: aiService.moodEngine.currentMood.systemIcon)
                                        .foregroundColor(aiService.moodEngine.currentMood.color)
                                        .imageScale(.large)
                                }
                                .sheet(isPresented: $showingMoodSelector) {
                                    MoodView(moodEngine: aiService.moodEngine)
                                }
                                
                                Button(action: { 
                                    self.showingDocsPicker.toggle()
                                    aiService.trackInteraction(type: "create_mixtape_button")
                                }) {
                                    Image(systemName: "plus").imageScale(.large)
                                }
                                .sheet(isPresented: self.$showingDocsPicker) {
                                    NewMixTapeView(
                                        isPresented: self.$showingDocsPicker,
                                        aiService: self.aiService
                                    ).environment(\.managedObjectContext, self.moc)
                                }
                            }
                    )
                }
                
                // Enhanced now playing bar with mood awareness
                NowPlayingButtonView(
                    showingNowPlayingSheet: $showingNowPlayingSheet,
                    queuePlayer: self.queuePlayer,
                    currentItemObserver: self.playerItemObserver,
                    currentSongName: self.currentSongName,
                    isPlaying: self.isPlaying,
                    aiService: self.aiService
                )
                .padding([.vertical])
                .sheet(isPresented: self.$showingNowPlayingSheet) {
                    PlayerView(
                        currentMixTapeName: self.$currentMixTapeName,
                        currentMixTapeImage: self.$currentMixTapeImage,
                        queuePlayer: self.queuePlayer,
                        playerItemObserver: self.playerItemObserver,
                        playerStatusObserver: self.playerStatusObserver,
                        currentPlayerItems: self.currentPlayerItems,
                        currentSongName: self.currentSongName,
                        isPlaying: self.isPlaying,
                        aiService: self.aiService
                    )
                }
            }
            .onAppear {
                // Track session start
                trackSessionStart()
                
                // Check if first launch
                if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                    showingOnboarding = true
                }
            }
            .onDisappear {
                // Track session end
                trackSessionEnd()
            }
            
            // Conditional onboarding sheet
            if showingOnboarding {
                OnboardingView(
                    personalityEngine: aiService.personalityEngine,
                    isShowingOnboarding: $showingOnboarding
                )
                .transition(.opacity)
                .zIndex(1)
                .onDisappear {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                }
            }
        }
        .animation(.spring(), value: showingOnboarding)
    }
    
    // Mood-based recommendations section
    var moodRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("For Your \(aiService.moodEngine.currentMood.rawValue) Mood")
                    .font(.headline)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    aiService.trackInteraction(type: "refresh_mood_recommendations")
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(aiService.moodEngine.getMoodBasedRecommendations().prefix(5), id: \.wrappedTitle) { mixtape in
                        NavigationLink(destination:
                            MixTapeView(
                                songs: mixtape.songsArray,
                                mixTape: mixtape,
                                currentMixTapeName: self.$currentMixTapeName,
                                currentMixTapeImage: self.$currentMixTapeImage,
                                queuePlayer: self.queuePlayer,
                                currentStatusObserver: self.playerStatusObserver,
                                currentItemObserver: self.playerItemObserver,
                                currentPlayerItems: self.currentPlayerItems,
                                currentSongName: self.currentSongName,
                                isPlaying: self.isPlaying,
                                aiService: self.aiService
                            ).environment(\.managedObjectContext, self.moc)
                        ) {
                            VStack(alignment: .leading) {
                                // Mixtape preview
                                if mixtape.urlData != nil {
                                    Image(uiImage: getCoverArtImage(url: mixtape.wrappedUrl))
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 140, height: 140)
                                        .cornerRadius(12)
                                } else {
                                    ZStack {
                                        Rectangle()
                                            .fill(aiService.moodEngine.currentMood.color.opacity(0.2))
                                            .frame(width: 140, height: 140)
                                            .cornerRadius(12)
                                        
                                        Image(systemName: aiService.moodEngine.currentMood.systemIcon)
                                            .font(.system(size: 40))
                                            .foregroundColor(aiService.moodEngine.currentMood.color)
                                    }
                                }
                                
                                Text(mixtape.wrappedTitle)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text("\(mixtape.numberOfSongs) songs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 140)
                            .onTapGesture {
                                aiService.trackInteraction(
                                    type: "select_mood_recommendation",
                                    mixtape: mixtape
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .background(
                Rectangle()
                    .fill(aiService.moodEngine.currentMood.color.opacity(0.05))
            )
        }
    }
    
    // Combined adaptive list content based on personality & mood
    var adaptiveListContent: some View {
        Group {
            // Different layouts based on dominant personality with mood influences
            if aiService.personalityEngine.currentPersonality == .explorer {
                // Explorer emphasizes discovery with mood influences
                explorerLayout
            } else if aiService.personalityEngine.currentPersonality == .curator {
                // Curator emphasizes organization with mood influences
                curatorLayout
            } else if aiService.personalityEngine.currentPersonality == .enthusiast {
                // Enthusiast emphasizes deep diving with mood influences
                enthusiastLayout
            } else if aiService.personalityEngine.currentPersonality == .social {
                // Social emphasizes sharing with mood influences
                socialLayout
            } else if aiService.personalityEngine.currentPersonality == .ambient {
                // Ambient emphasizes mood-based organization
                ambientLayout
            } else if aiService.personalityEngine.currentPersonality == .analyzer {
                // Analyzer emphasizes technical details with mood influences
                analyzerLayout
            } else {
                // Default layout with mood influences
                defaultLayout
            }
        }
    }
    
    // Explorer layout emphasizing discovery
    var explorerLayout: some View {
        ScrollView {
            VStack(spacing: 24) {
                // AI-recommended section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Discover")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text("Personalized recommendations just for you")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(aiService.getPersonalizedRecommendations().prefix(5), id: \.wrappedTitle) { mixtape in
                                NavigationLink(destination:
                                    MixTapeView(
                                        songs: mixtape.songsArray,
                                        mixTape: mixtape,
                                        currentMixTapeName: self.$currentMixTapeName,
                                        currentMixTapeImage: self.$currentMixTapeImage,
                                        queuePlayer: self.queuePlayer,
                                        currentStatusObserver: self.playerStatusObserver,
                                        currentItemObserver: self.playerItemObserver,
                                        currentPlayerItems: self.currentPlayerItems,
                                        currentSongName: self.currentSongName,
                                        isPlaying: self.isPlaying,
                                        aiService: self.aiService
                                    ).environment(\.managedObjectContext, self.moc)
                                ) {
                                    VStack(alignment: .leading) {
                                        // Mixtape preview
                                        if mixtape.urlData != nil {
                                            Image(uiImage: getCoverArtImage(url: mixtape.wrappedUrl))
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 160, height: 160)
                                                .cornerRadius(8)
                                        } else {
                                            ZStack {
                                                Rectangle()
                                                    .fill(aiService.personalityEngine.currentPersonality.themeColor.opacity(0.2))
                                                    .frame(width: 160, height: 160)
                                                    .cornerRadius(8)
                                                
                                                Image(systemName: "music.note.list")
                                                    .font(.system(size: 40))
                                                    .foregroundColor(aiService.personalityEngine.currentPersonality.themeColor)
                                            }
                                        }
                                        
                                        Text(mixtape.wrappedTitle)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        Text("\(mixtape.numberOfSongs) songs")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 160)
                                    .onTapGesture {
                                        aiService.trackInteraction(
                                            type: "select_discovery_recommendation",
                                            mixtape: mixtape
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                }
                
                // All mixtapes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Mixtapes")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if mixTapes.isEmpty {
                        EmptyStateView(
                            title: "Start Your Discovery",
                            message: "Create your first mixtape to begin exploring music in a new way",
                            systemImage: "safari",
                            action: { 
                                self.showingDocsPicker.toggle()
                                aiService.trackInteraction(type: "empty_state_create_mixtape")
                            }
                        )
                    } else {
                        ForEach(mixTapes, id:\.wrappedTitle) { tape in
                            NavigationLink(destination:
                                MixTapeView(
                                    songs: tape.songsArray,
                                    mixTape: tape,
                                    currentMixTapeName: self.$currentMixTapeName,
                                    currentMixTapeImage: self.$currentMixTapeImage,
                                    queuePlayer: self.queuePlayer,
                                    currentStatusObserver: self.playerStatusObserver,
                                    currentItemObserver: self.playerItemObserver,
                                    currentPlayerItems: self.currentPlayerItems,
                                    currentSongName: self.currentSongName,
                                    isPlaying: self.isPlaying,
                                    aiService: self.aiService
                                ).environment(\.managedObjectContext, self.moc)
                            ) {
                                HStack {
                                    if tape.urlData != nil {
                                        Image(uiImage: getCoverArtImage(url: tape.wrappedUrl))
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 60, height: 60)
                                            .cornerRadius(6)
                                    } else {
                                        ZStack {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(width: 60, height: 60)
                                                .cornerRadius(6)
                                            
                                            Image(systemName: "music.note")
                                                .font(.system(size: 24))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(tape.wrappedTitle)
                                            .font(.headline)
                                        
                                        Text("\(tape.numberOfSongs) songs")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        // Play the mixtape
                                        playMixtape(tape)
                                        aiService.trackInteraction(type: "play_from_list", mixtape: tape)
                                    }) {
                                        Image(systemName: "play.fill")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(width: 36, height: 36)
                                            .background(Circle().fill(aiService.personalityEngine.currentPersonality.themeColor))
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    aiService.trackInteraction(type: "select_mixtape", mixtape: tape)
                                }
                            }
                        }
                        .onDelete(perform: deleteMixTape)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.top, 8)
        }
    }
    
    // Curator layout emphasizing organization
    var curatorLayout: some View {
        List {
            if mixTapes.isEmpty {
                EmptyStateView(
                    title: "Curate Your Collection",
                    message: "Start building your perfectly organized music library",
                    systemImage: "folder.fill",
                    action: { 
                        self.showingDocsPicker.toggle()
                        aiService.trackInteraction(type: "empty_state_create_mixtape")
                    }
                )
            } else {
                // Recently played section
                if currentSongName.name != "Not Playing" {
                    Section(header: Text("Recently Played")) {
                        let filteredTapes = mixTapes.filter { tape in
                            tape.wrappedTitle == currentMixTapeName
                        }
                        
                        ForEach(filteredTapes, id: \.wrappedTitle) { tape in
                            NavigationLink(destination:
                                MixTapeView(
                                    songs: tape.songsArray,
                                    mixTape: tape,
                                    currentMixTapeName: self.$currentMixTapeName,
                                    currentMixTapeImage: self.$currentMixTapeImage,
                                    queuePlayer: self.queuePlayer,
                                    currentStatusObserver: self.playerStatusObserver,
                                    currentItemObserver: self.playerItemObserver,
                                    currentPlayerItems: self.currentPlayerItems,
                                    currentSongName: self.currentSongName,
                                    isPlaying: self.isPlaying,
                                    aiService: self.aiService
                                ).environment(\.managedObjectContext, self.moc)
                            ) {
                                mixtapeRow(tape)
                            }
                            .onTapGesture {
                                aiService.trackInteraction(type: "select_recent_mixtape", mixtape: tape)
                            }
                        }
                    }
                }
                
                // All mixtapes organized by size
                Section(header: Text("All Mixtapes")) {
                    let sortedTapes = mixTapes.sorted { $0.numberOfSongs > $1.numberOfSongs }
                    
                    ForEach(sortedTapes, id: \.wrappedTitle) { tape in
                        NavigationLink(destination:
                            MixTapeView(
                                songs: tape.songsArray,
                                mixTape: tape,
                                currentMixTapeName: self.$currentMixTapeName,
                                currentMixTapeImage: self.$currentMixTapeImage,
                                queuePlayer: self.queuePlayer,
                                currentStatusObserver: self.playerStatusObserver,
                                currentItemObserver: self.playerItemObserver,
                                currentPlayerItems: self.currentPlayerItems,
                                currentSongName: self.currentSongName,
                                isPlaying: self.isPlaying,
                                aiService: self.aiService
                            ).environment(\.managedObjectContext, self.moc)
                        ) {
                            mixtapeRow(tape)
                        }
                        .onTapGesture {
                            aiService.trackInteraction(type: "select_mixtape", mixtape: tape)
                        }
                    }
                    .onDelete(perform: deleteMixTape)
                }
                
                // Mood-specific section
                moodBasedSection
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    // For brevity, placeholder methods for the other layouts
    var enthusiastLayout: some View {
        // Implementation would be similar to curatorLayout but with focus on deep diving
        defaultLayout
    }
    
    var socialLayout: some View {
        // Implementation would be similar but with focus on sharing
        defaultLayout
    }
    
    var ambientLayout: some View {
        // Implementation would be similar but with focus on background listening
        defaultLayout
    }
    
    var analyzerLayout: some View {
        // Implementation would be similar but with focus on technical details
        defaultLayout
    }
    
    // Default layout as fallback
    var defaultLayout: some View {
        List {
            if mixTapes.isEmpty {
                EmptyStateView(
                    title: "No Mixtapes Yet",
                    message: "Create your first mixtape to start organizing your music collection",
                    systemImage: "music.note.list",
                    action: { 
                        self.showingDocsPicker.toggle()
                        aiService.trackInteraction(type: "empty_state_create_mixtape")
                    }
                )
            } else {
                ForEach(mixTapes, id:\.wrappedTitle) { tape in
                    NavigationLink(destination:
                        MixTapeView(
                            songs: tape.songsArray,
                            mixTape: tape,
                            currentMixTapeName: self.$currentMixTapeName,
                            currentMixTapeImage: self.$currentMixTapeImage,
                            queuePlayer: self.queuePlayer,
                            currentStatusObserver: self.playerStatusObserver,
                            currentItemObserver: self.playerItemObserver,
                            currentPlayerItems: self.currentPlayerItems,
                            currentSongName: self.currentSongName,
                            isPlaying: self.isPlaying,
                            aiService: self.aiService
                        ).environment(\.managedObjectContext, self.moc)
                    ) {
                        mixtapeRow(tape)
                    }
                    .onTapGesture {
                        aiService.trackInteraction(type: "select_mixtape", mixtape: tape)
                    }
                }
                .onDelete(perform: deleteMixTape)
            }
        }
    }
    
    // Mood-based section that can be included in various layouts
    var moodBasedSection: some View {
        Section(header: Text("For Your \(aiService.moodEngine.currentMood.rawValue) Mood")) {
            let recommendations = aiService.moodEngine.getMoodBasedRecommendations().prefix(3)
            
            ForEach(Array(recommendations), id: \.wrappedTitle) { tape in
                NavigationLink(destination:
                    MixTapeView(
                        songs: tape.songsArray,
                        mixTape: tape,
                        currentMixTapeName: self.$currentMixTapeName,
                        currentMixTapeImage: self.$currentMixTapeImage,
                        queuePlayer: self.queuePlayer,
                        currentStatusObserver: self.playerStatusObserver,
                        currentItemObserver: self.playerItemObserver,
                        currentPlayerItems: self.currentPlayerItems,
                        currentSongName: self.currentSongName,
                        isPlaying: self.isPlaying,
                        aiService: self.aiService
                    ).environment(\.managedObjectContext, self.moc)
                ) {
                    HStack {
                        // Mixtape image with mood indicator
                        ZStack {
                            if tape.urlData != nil {
                                Image(uiImage: getCoverArtImage(url: tape.wrappedUrl))
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(6)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(6)
                                
                                Image(systemName: "music.note")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                            }
                            
                            // Mood indicator
                            Circle()
                                .fill(aiService.moodEngine.currentMood.color)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Image(systemName: aiService.moodEngine.currentMood.systemIcon)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 20, y: 20)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tape.wrappedTitle)
                                .font(.subheadline)
                            
                            Text("\(tape.numberOfSongs) songs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onTapGesture {
                    aiService.trackInteraction(type: "select_mood_mixtape", mixtape: tape)
                }
            }
        }
    }
    
    // Helper function to create consistent mixtape rows
    func mixtapeRow(_ tape: MixTape) -> some View {
        HStack {
            if tape.urlData != nil {
                Image(uiImage: getCoverArtImage(url: tape.wrappedUrl))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .cornerRadius(6)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tape.wrappedTitle)
                    .font(.subheadline)
                
                Text("\(tape.numberOfSongs) songs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // Helper function to play a mixtape
    func playMixtape(_ tape: MixTape) {
        if currentMixTapeName != tape.wrappedTitle {
            currentMixTapeName = tape.wrappedTitle
            currentMixTapeImage = tape.wrappedUrl
        }
        
        let newPlayerItems = createArrayOfPlayerItems(songs: tape.songsArray)
        if currentPlayerItems.items != newPlayerItems {
            currentPlayerItems.items = newPlayerItems
        }
        
        loadPlayer(arrayOfPlayerItems: currentPlayerItems.items, player: queuePlayer)
        queuePlayer.play()
    }
    
    // Track user interactions for AI analysis
    func trackSessionStart() {
        aiService.trackInteraction(type: "session_start")
    }
    
    func trackSessionEnd() {
        aiService.trackInteraction(type: "session_end")
    }
    
    // MARK: - Other Utility Functions
    
    func deleteMixTape(offsets: IndexSet) {
        for index in offsets {
            let tape = mixTapes[index]
            aiService.trackInteraction(type: "delete_mixtape", mixtape: tape)
            moc.delete(tape)
        }
        do {
            try moc.save()
        } catch {
            print(error)
        }
    }
}

// MARK: - NowPlayingButtonView with Mood

extension NowPlayingButtonView {
    // Add mood-aware body to NowPlayingButtonView
    var moodAwareBody: some View {
        HStack {
            Button(action: {
                self.showingNowPlayingSheet.toggle()
                aiService.trackInteraction(type: "open_player")
            }) {
                HStack() {
                    Button(action: {
                        if self.isPlaying.value {
                            self.queuePlayer.pause()
                            aiService.trackInteraction(type: "pause")
                        } else {
                            self.queuePlayer.play()
                            aiService.trackInteraction(type: "play")
                        }
                    }) {
                        Image(systemName: self.isPlaying.value ? "pause.fill" : "play.fill").imageScale(.large)
                    }
                    
                    Spacer()
                    
                    // Add mood indicator
                    HStack {
                        Text(self.currentSongName.name)
                            .onReceive(currentItemObserver.$currentItem) { item in
                                self.currentSongName.name = getItemName(playerItem: item)
                        }
                        
                        if self.currentSongName.name != "Not Playing" {
                            Circle()
                                .fill(aiService.moodEngine.currentMood.color)
                                .frame(width: 12, height: 12)
                        }
                    }
               }
               .padding()
               .background(
                   LinearGradient(
                       gradient: Gradient(
                           colors: [
                               aiService.personalityEngine.currentPersonality.themeColor.opacity(0.8),
                               aiService.moodEngine.currentMood.color.opacity(0.6)
                           ]
                       ),
                       startPoint: .leading,
                       endPoint: .trailing
                   )
               )
               .foregroundColor(Color.white)
               .cornerRadius(12)
           }
        }
    }
}

// MARK: - NewMixTapeView Extensions

extension NewMixTapeView {
    // Add this function to initialize suggested titles
    func loadSuggestedTitles() {
        var titles: [String] = []
        
        // Get mood-based suggestions
        if let moodEngine = aiService?.moodEngine {
            for action in moodEngine.getMoodBasedActions() {
                if action.action.contains("create_mixtape_") {
                    let title = action.title
                    if !titles.contains(title) {
                        titles.append(title)
                    }
                }
            }
        }
        
        // Get personality-based suggestions
        if let personalityEngine = aiService?.personalityEngine,
           let recommendationEngine = aiService?.recommendationEngine {
            
            let personalitySuggestions = recommendationEngine.getSuggestedMixtapeTitles()
            for title in personalitySuggestions {
                if !titles.contains(title) {
                    titles.append(title)
                }
            }
        }
        
        // Ensure we have at least some default suggestions
        if titles.isEmpty {
            titles = [
                "My Mixtape",
                "Favorites Collection",
                "New Mixtape",
                "Playlist 1",
                "Music Collection"
            ]
        }
        
        suggestedTitles = titles
    }
}
