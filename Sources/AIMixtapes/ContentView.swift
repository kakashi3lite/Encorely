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
import AIMixtapes // Contains SharedTypes

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
        ZStack {
            VStack(spacing: 0) {
                // AI insights banner at the top
                AIInsightsView(aiService: aiService)
                    .padding(.top, 8)
                    .padding(.horizontal, 8)
                
                // Personalized message banner
                PersonalizedMessageBanner(aiService: aiService)
                    .padding(.vertical, 8)
                
                NavigationView {
                    VStack(spacing: 0) {
                        // Mood-aware recommendations section if applicable
                        if aiService.moodEngine.moodConfidence > 0.3 {
                            moodRecommendationsSection
                                .padding(.bottom, 8)
                        }
                        
                        // Main mixtape list
                        mixtapeListView
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
                                    self.showingMoodSelector.toggle()
                                    aiService.trackInteraction(type: "open_mood_selector")
                                }) {
                                    Image(systemName: aiService.moodEngine.currentMood.systemIcon)
                                        .imageScale(.large)
                                        .foregroundColor(aiService.moodEngine.currentMood.color)
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
                                    NewMixTapeView(isPresented: self.$showingDocsPicker, aiService: self.aiService)
                                        .environment(\.managedObjectContext, self.moc)
                                }
                            }
                    )
                }
                
                // Enhanced now playing button
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
                // Check if first launch
                if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                    showingOnboarding = true
                }
                
                // Track session start
                aiService.trackInteraction(type: "session_start")
            }
            .onDisappear {
                // Track session end
                aiService.trackInteraction(type: "session_end")
            }
            
            // Conditional onboarding overlay
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
    
    // MARK: - Component Views
    
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
                    // Convert recommendations to an array we can use
                    let recommendations = aiService.getPersonalizedRecommendations()
                    
                    ForEach(recommendations.prefix(5), id: \.wrappedTitle) { mixtape in
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
                                // Mixtape cover art
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
    
    // Main mixtape list view
    var mixtapeListView: some View {
        Group {
            if mixTapes.isEmpty {
                EmptyStateView(
                    title: "Start Your Collection",
                    message: "Create your first mixtape to begin exploring music in a new way",
                    systemImage: "music.note.list",
                    action: { 
                        self.showingDocsPicker.toggle()
                        aiService.trackInteraction(type: "empty_state_create_mixtape")
                    }
                )
            } else {
                // Choose display style based on personality
                switch aiService.personalityEngine.currentPersonality {
                case .explorer:
                    gridListView
                case .curator:
                    detailedListView
                default:
                    standardListView
                }
            }
        }
    }
    
    // Standard list view
    var standardListView: some View {
        List {
            ForEach(mixTapes, id: \.wrappedTitle) { tape in
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
                    Text(tape.wrappedTitle)
                }
            }
            .onDelete(perform: deleteMixTape)
        }
    }
    
    // Grid list view for explorers
    var gridListView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(mixTapes, id: \.wrappedTitle) { tape in
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
                        VStack(alignment: .leading) {
                            if tape.urlData != nil {
                                Image(uiImage: getCoverArtImage(url: tape.wrappedUrl))
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 160)
                                    .cornerRadius(12)
                            } else {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 160)
                                        .cornerRadius(12)
                                    
                                    Image(systemName: "music.note")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Text(tape.wrappedTitle)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Text("\(tape.numberOfSongs) songs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        Button(action: {
                            self.moc.delete(tape)
                            try? self.moc.save()
                            aiService.trackInteraction(type: "delete_mixtape", mixtape: tape)
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // Detailed list view for curators
    var detailedListView: some View {
        List {
            ForEach(mixTapes, id: \.wrappedTitle) { tape in
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
                                
                            // Mood tag if available
                            if let moodTags = tape.moodTags, !moodTags.isEmpty {
                                Text(moodTags)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        // Quick play button
                        Button(action: {
                            playMixtape(tape)
                            aiService.trackInteraction(type: "play_from_list", mixtape: tape)
                        }) {
                            Image(systemName: "play.fill")
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.blue))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteMixTape)
        }
    }
    
    // MARK: - Helper Functions
    
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
        
        // Track play in mixtape model
        tape.trackPlay()
        try? moc.save()
    }
}

// MARK: - NewMixTapeView with AI

struct NewMixTapeView: View {
    // Environment and state
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: MixTape.entity(), sortDescriptors: []) var mixTapes: FetchedResults<MixTape>
    
    // State variables
    @State var tapeTitle: String = ""
    @State private var showingDocsPicker: Bool = false
    @State private var showingImagePicker: Bool = false
    @State var mixTapePicked: Bool = false
    @State var imagePicked: Bool = false
    @Binding var isPresented: Bool
    
    // AI service
    var aiService: AIIntegrationService
    
    // AI-suggested titles
    @State private var suggestedTitles: [String] = []
    
    // Validate mixtape name
    var inValidName: Bool {
        // mixtape names must be unique to preserve NavigationView functionality
        let bool = mixTapes.contains{ $0.title == tapeTitle }
        return bool
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Mixtape Name")) {
                    TextField("Enter Mixtape Name: ", text: $tapeTitle)
                }
                .disabled(mixTapePicked)
                
                // AI suggested names
                Section(header: Text("Suggested Names")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(suggestedTitles, id: \.self) { title in
                                Button(action: {
                                    self.tapeTitle = title
                                    aiService.trackInteraction(type: "select_suggested_title")
                                }) {
                                    Text(title)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(self.tapeTitle == title ? 
                                                     aiService.personalityEngine.currentPersonality.themeColor : Color.gray.opacity(0.1))
                                        )
                                        .foregroundColor(self.tapeTitle == title ? .white : .primary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Mood tags selection
                Section(header: Text("Mood Tags (Optional)")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Mood.allCases, id: \.self) { mood in
                                Button(action: {
                                    // In a real app, we would store selected moods for the new mixtape
                                    aiService.trackInteraction(type: "select_mood_tag_\(mood.rawValue)")
                                }) {
                                    HStack {
                                        Image(systemName: mood.systemIcon)
                                            .foregroundColor(mood.color)
                                        
                                        Text(mood.rawValue)
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(mood.color, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Add songs section
                Section {
                    Button(action: { self.showingDocsPicker.toggle() }) {
                         HStack {
                             Image(systemName: "folder.badge.plus").imageScale(.large)
                             Text("Add Songs")
                         }
                     }
                     .sheet(isPresented: self.$showingDocsPicker) {
                      MixTapePicker(nameofTape: self.tapeTitle, mixTapePicked: self.$mixTapePicked, moc: self.moc)
                     }
                }
                .disabled(tapeTitle.isEmpty || inValidName || mixTapePicked)
                
                // Add cover image section
                Section {
                    Button(action: { self.showingImagePicker.toggle() }) {
                        HStack {
                            Image(systemName: "photo").imageScale(.large)
                            Text("Add Cover Image")
                        }
                     }
                     .sheet(isPresented: self.$showingImagePicker) {
                        ImagePickerView(mixTapes: self.mixTapes, moc: self.moc, imagePicked: self.$imagePicked)
                     }
                }
                .disabled(imagePicked || !mixTapePicked)
                
                // Finish section
                Section {
                    Button(action: { 
                        self.isPresented.toggle()
                        aiService.trackInteraction(type: "create_mixtape")
                    }) {
                        Text("Add Mixtape")
                    }
                }
                .disabled(!mixTapePicked)
            }
            .navigationBarTitle("New Mixtape", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                self.isPresented.toggle()
            })
            .onAppear {
                loadSuggestedTitles()
                aiService.trackInteraction(type: "open_create_mixtape")
            }
        }
    }
    
    // Load AI-suggested mixtape titles
    func loadSuggestedTitles() {
        // Get suggestions from recommendation engine
        let recommendedTitles = aiService.recommendationEngine.getSuggestedMixtapeTitles()
        suggestedTitles = recommendedTitles
    }
}

// MARK: - NowPlayingButtonView with AI

struct NowPlayingButtonView: View {
    // Core properties
    @Binding var showingNowPlayingSheet: Bool
    let queuePlayer: AVQueuePlayer
    let currentItemObserver: PlayerItemObserver
    @ObservedObject var currentSongName: CurrentSongName
    @ObservedObject var isPlaying: IsPlaying
    
    // AI service
    var aiService: AIIntegrationService
    
    var body: some View {
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
                    
                    // Enhanced display with mood indicator
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

// MARK: - Enhanced PlayerView with AI

struct PlayerView: View {
    // Core properties
    @Binding var currentMixTapeName: String
    @Binding var currentMixTapeImage: URL
    let queuePlayer: AVQueuePlayer
    let playerItemObserver: PlayerItemObserver
    let playerStatusObserver: PlayerStatusObserver
    @ObservedObject var currentPlayerItems: CurrentPlayerItems
    @ObservedObject var currentSongName: CurrentSongName
    @ObservedObject var isPlaying: IsPlaying
    
    // AI service
    var aiService: AIIntegrationService
    
    // State for mood-related features
    @State private var showingMoodPicker: Bool = false
    @State private var showingReorderOptions: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                // Cover art with mood indicator overlay
                ZStack(alignment: .topTrailing) {
                    if self.currentMixTapeName != "" {
                        Image(uiImage: getCoverArtImage(url: self.currentMixTapeImage))
                             .resizable()
                             .frame(width: geometry.size.width - 24, height: geometry.size.width - 24)
                             .cornerRadius(16)
                             .shadow(radius: 10)

                    } else {
                        ZStack {
                            Rectangle()
                                .fill(aiService.moodEngine.currentMood.color.opacity(0.2))
                                .frame(width: geometry.size.width - 24, height: geometry.size.width - 24)
                                .cornerRadius(16)
                                .shadow(radius: 10)
                            
                            Image(systemName: "hifispeaker.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100)
                                .foregroundColor(aiService.moodEngine.currentMood.color)
                        }
                    }
                    
                    // Mood indicator
                    Button(action: {
                        self.showingMoodPicker.toggle()
                        aiService.trackInteraction(type: "open_mood_picker_from_player")
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 44, height: 44)
                                .shadow(radius: 3)
                            
                            Circle()
                                .fill(aiService.moodEngine.currentMood.color)
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: aiService.moodEngine.currentMood.systemIcon)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 16)
                        .padding(.trailing, 16)
                    }
                    .sheet(isPresented: $showingMoodPicker) {
                        MoodView(moodEngine: aiService.moodEngine)
                    }
                }

                // Song and mixtape info
                VStack {
                    Text(self.currentSongName.name)
                            .font(Font.system(.title).bold())
                            .lineLimit(1)
                    
                    Text(self.currentMixTapeName)
                        .font(Font.system(.title))
                        .lineLimit(1)
                }
               
                // Playback controls
                HStack(spacing: 40) {
                    Button(action: { 
                        skipBack(currentPlayerItems: self.currentPlayerItems.items, currentSongName: self.currentSongName.name, queuePlayer: self.queuePlayer, isPlaying: self.isPlaying.value)
                        aiService.trackInteraction(type: "previous_song")
                    }) {
                        ZStack {
                            Circle()
                                .frame(width: 80, height: 80)
                                .foregroundColor(aiService.personalityEngine.currentPersonality.themeColor)
                                .shadow(radius: 10)
                            Image(systemName: "backward.fill")
                                .foregroundColor(.white)
                                .font(.system(.title))
                        }
                    }

                    Button(action: {
                        if self.isPlaying.value {
                            self.queuePlayer.pause()
                            aiService.trackInteraction(type: "pause")
                        } else {
                            self.queuePlayer.play()
                            aiService.trackInteraction(type: "play")
                        }
                        
                    }) {
                        ZStack {
                            Circle()
                                .frame(width: 80, height: 80)
                                .foregroundColor(aiService.personalityEngine.currentPersonality.themeColor)
                                .shadow(radius: 10)
                            Image(systemName: self.isPlaying.value ? "pause.fill" : "play.fill").imageScale(.large)
                                .foregroundColor(.white)
                                .font(.system(.title))
                        }
                    }

                    Button(action: {
                        self.queuePlayer.currentItem?.seek(to: CMTime.zero, completionHandler: nil)
                        self.queuePlayer.advanceToNextItem()
                        aiService.trackInteraction(type: "skip_song")
                    }) {
                        ZStack {
                            Circle()
                                .frame(width: 80, height: 80)
                                .foregroundColor(aiService.personalityEngine.currentPersonality.themeColor)
                                .shadow(radius: 10)
                            Image(systemName: "forward.fill")
                                .foregroundColor(.white)
                                .font(.system(.title))
                        }
                    }
                }
                
                // AI reordering button
                if currentMixTapeName != "" {
                    Button(action: {
                        self.showingReorderOptions.toggle()
                        aiService.trackInteraction(type: "mood_reorder_options")
                    }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .font(.system(.body))
                            
                            Text("Smart Reordering")
                                .font(.system(.body))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            aiService.moodEngine.currentMood.color,
                                            aiService.personalityEngine.currentPersonality.themeColor
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(radius: 3)
                    }
                    .actionSheet(isPresented: $showingReorderOptions) {
                        ActionSheet(
                            title: Text("Smart Reordering"),
                            message: Text("Choose how to reorder songs based on mood"),
                            buttons: [
                                .default(Text("Energize: Start relaxed, build energy")) {
                                    // In a real app, we would implement this reordering
                                    aiService.trackInteraction(type: "reorder_relaxed_to_energetic")
                                },
                                .default(Text("Wind Down: Start energetic, end relaxed")) {
                                    aiService.trackInteraction(type: "reorder_energetic_to_relaxed")
                                },
                                .default(Text("Maintain Current Mood")) {
                                    aiService.trackInteraction(type: "reorder_maintain_mood")
                                },
                                .cancel()
                            ]
                        )
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - MixTapeView with AI

extension MixTapeView {
    // Add AI service to MixTapeView
    var aiService: AIIntegrationService? { nil }
}
