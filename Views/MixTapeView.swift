//
//  MixTapeView.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import SwiftUI
import CoreData
import AVKit
import AIMixtapes // Contains SharedTypes

/// Enhanced MixTapeView with AI features and error handling
struct MixTapeView: View {
    // MARK: - Properties
    
    @Environment(\.managedObjectContext) var moc
    @State var songs: [Song]
    @State var mixTape: MixTape
    @Binding var currentMixTapeName: String
    @Binding var currentMixTapeImage: URL
    
    // Playback properties
    let queuePlayer: AVQueuePlayer
    let currentStatusObserver: PlayerStatusObserver
    let currentItemObserver: PlayerItemObserver
    @ObservedObject var currentPlayerItems: CurrentPlayerItems
    @ObservedObject var currentSongName: CurrentSongName
    @ObservedObject var isPlaying: IsPlaying
    
    // AI service
    var aiService: AIIntegrationService
    
    // Enhanced state
    @State private var showingDocsPicker = false
    @State private var showingSmartReorder = false
    @State private var showingSimilarMixtapes = false
    @State private var showingAIAnalysis = false
    @State private var selectedMoods: Set<Mood> = []
    @State private var isAnalyzing = false
    @State private var reorderInProgress = false
    @State private var retryAction: (() -> Void)?
    @State private var currentError: AppError?
    @State private var selectedSongId: String?
    @State private var showingVisualization = false
    @State private var scrollOffset: CGFloat = 0
    @State private var viewMode: ViewMode = .list
    
    private let headerHeight: CGFloat = 200
    
    enum ViewMode: String, CaseIterable {
        case list = "List"
        case grid = "Grid" 
        case compact = "Compact"
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            case .compact: return "list.dash"
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // Parallax header
                    GeometryReader { geometry in
                        let minY = geometry.frame(in: .global).minY
                        let progress = max(0, min(1, -minY / headerHeight))
                        
                        headerView
                            .frame(height: max(headerHeight - minY, headerHeight/2))
                            .blur(radius: progress * 10)
                            .opacity(1 - progress)
                    }
                    .frame(height: headerHeight)
                    
                    // Error banner if needed
                    if let error = currentError {
                        ErrorBanner(error: error) {
                            retryAction?()
                        }
                    }
                    
                    VStack(spacing: 24) {
                        // Mood tags section
                        moodTagsSection
                            .horizontalSlideTransition(isVisible: !getMoodTags().isEmpty)
                        
                        // Action buttons
                        actionButtonsSection
                        
                        // Songs list with view mode toggle
                        songListHeader
                        
                        switch viewMode {
                        case .list:
                            listView
                        case .grid:
                            gridView
                        case .compact:
                            compactView
                        }
                    }
                    .padding(.top)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
                            .edgesIgnoringSafeArea(.bottom)
                    )
                    .offset(y: -20)
                }
            }
            .edgesIgnoringSafeArea(.top)
            
            // Bottom player bar
            if let currentSong = songs.first(where: { $0.title == currentSongName.wrappedValue }) {
                VStack(spacing: 0) {
                    // Progress bar
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(aiService.moodEngine.currentMood.color)
                            .frame(width: geometry.size.width * 0.4) // Replace with actual progress
                            .animation(.linear, value: currentSong.title)
                    }
                    .frame(height: 2)
                    
                    PlaybackControlsView(
                        song: currentSong,
                        isPlaying: isPlaying,
                        onPlayPause: togglePlayback,
                        onNext: playNextSong,
                        onPrevious: playPreviousSong
                    )
                }
                .transition(.move(edge: .bottom))
            }
        }
        .navigationBarTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { viewMode = .list }) {
                        Label("List View", systemImage: "list.bullet")
                    }
                    Button(action: { viewMode = .grid }) {
                        Label("Grid View", systemImage: "square.grid.2x2")
                    }
                    Button(action: { viewMode = .compact }) {
                        Label("Compact View", systemImage: "list.dash")
                    }
                    
                    Divider()
                    
                    Button(action: { showingAIAnalysis = true }) {
                        Label("AI Analysis", systemImage: "chart.bar.xaxis")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.large)
                }
            }
        }
        .sheet(isPresented: $showingSmartReorder) {
            SmartReorderView(mixTape: mixTape, aiService: aiService)
        }
        .sheet(isPresented: $showingSimilarMixtapes) {
            SimilarMixtapesView(originalMixtape: mixTape, aiService: aiService)
        }
        .sheet(isPresented: $showingDocsPicker) {
            DocumentPicker(mixTape: mixTape)
        }
        .sheet(isPresented: $showingAIAnalysis) {
            MixtapeAnalysisView(mixTape: mixTape, aiService: aiService)
        }
        .sheet(isPresented: $showingVisualization) {
            AudioVisualizationView(
                queuePlayer: queuePlayer,
                aiService: aiService,
                currentSongName: currentSongName
            )
        }
    }
    
    // MARK: - Components
    
    private var headerView: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    aiService.moodEngine.currentMood.color.opacity(0.8),
                    aiService.personalityEngine.currentPersonality.themeColor.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Content
            VStack(spacing: 16) {
                Text(mixTape.wrappedTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                HStack(spacing: 16) {
                    Label("\(songs.count) songs", systemImage: "music.note")
                    Label(formatDuration(songs.reduce(0) { $0 + ($1.duration ?? 0) }), systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            }
            .shadow(radius: 5)
        }
    }
    
    private var moodTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mood Tags")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(aiService.moodEngine.currentMood.color)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(getMoodTags(), id: \.self) { tag in
                        if let mood = Mood(rawValue: tag) {
                            MoodBadge(mood: mood) {
                                withAnimation {
                                    selectedMoodTags.contains(tag) ?
                                        selectedMoodTags.removeAll { $0 == tag } :
                                        selectedMoodTags.append(tag)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var actionButtonsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Smart Reorder
                ActionButton(
                    icon: "wand.and.stars",
                    title: "Smart Reorder",
                    color: aiService.moodEngine.currentMood.color,
                    action: { showingSmartReorder = true }
                )
                
                // Find Similar
                ActionButton(
                    icon: "rectangle.stack.person.crop",
                    title: "Find Similar",
                    color: aiService.personalityEngine.currentPersonality.themeColor,
                    action: {
                        showingSimilarMixtapes = true
                        aiService.trackInteraction(type: "find_similar", mixtape: mixTape)
                    }
                )
                
                // Add Songs
                ActionButton(
                    icon: "plus.circle",
                    title: "Add Songs",
                    color: .blue,
                    action: {
                        showingDocsPicker = true
                        aiService.trackInteraction(type: "add_songs", mixtape: mixTape)
                    }
                )
                
                // AI Analysis
                ActionButton(
                    icon: "waveform.path",
                    title: "AI Analysis",
                    color: .purple,
                    action: {
                        showingAIAnalysis = true
                        aiService.trackInteraction(type: "view_analysis", mixtape: mixTape)
                    }
                )
                
                // Visualize
                ActionButton(
                    icon: "chart.bar.xaxis",
                    title: "Visualize",
                    color: .orange,
                    action: { showingVisualization = true }
                )
            }
            .padding(.horizontal)
        }
    }
    
    private var songListHeader: some View {
        HStack {
            Text("Songs")
                .font(.headline)
            
            Spacer()
            
            Picker("View Mode", selection: $viewMode) {
                Image(systemName: "list.bullet").tag(ViewMode.list)
                Image(systemName: "square.grid.2x2").tag(ViewMode.grid)
                Image(systemName: "list.dash").tag(ViewMode.compact)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 120)
        }
        .padding(.horizontal)
    }
    
    private var listView: some View {
        VStack(spacing: 2) {
            ForEach(songs) { song in
                SongRowView(
                    song: song,
                    isPlaying: currentSongName.wrappedValue == song.title,
                    isSelected: selectedSongId == song.id,
                    onTap: { playSong(song) }
                )
                .contextMenu {
                    songContextMenu(for: song)
                }
                .onTapGesture {
                    withAnimation {
                        selectedSongId = song.id
                    }
                }
            }
            .onDelete(perform: deleteSongs)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var gridView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(songs) { song in
                SongGridCell(
                    song: song,
                    isPlaying: currentSongName.wrappedValue == song.title,
                    onTap: { playSong(song) }
                )
                .contextMenu {
                    songContextMenu(for: song)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var compactView: some View {
        VStack(spacing: 1) {
            ForEach(songs) { song in
                CompactSongRow(
                    song: song,
                    isPlaying: currentSongName.wrappedValue == song.title,
                    onTap: { playSong(song) }
                )
                .contextMenu {
                    songContextMenu(for: song)
                }
            }
            .onDelete(perform: deleteSongs)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return "\(minutes) min"
    }
    
    private func getMoodTags() -> [String] {
        return mixTape.moodTagsArray
    }
    
    /// Action sheet for smart reordering options
    private func smartReorderActionSheet() -> ActionSheet {
        ActionSheet(
            title: Text("Smart Reorder"),
            message: Text("Let AI reorder your songs based on mood progression"),
            buttons: [
                .default(Text("Energizing: Build Up Energy")) {
                    smartReorderSongs(startMood: .relaxed, endMood: .energetic)
                },
                .default(Text("Relaxing: Wind Down")) {
                    smartReorderSongs(startMood: .energetic, endMood: .relaxed)
                },
                .default(Text("Focus: Start and Stay Focused")) {
                    smartReorderSongs(startMood: .focused, endMood: .focused)
                },
                .default(Text("Happy Journey: Build to Joy")) {
                    smartReorderSongs(startMood: .neutral, endMood: .happy)
                },
                .default(Text("Emotional Arc: Build and Release")) {
                    smartReorderSongs(startMood: .melancholic, endMood: .relaxed)
                },
                .cancel()
            ]
        )
    }
    
    /// Reorder mixtape based on mood progression
    private func smartReorderSongs(startMood: Mood, endMood: Mood) {
        reorderInProgress = true
        
        let success = mixTape.reorderSongsForMoodProgression(
            startMood: startMood,
            endMood: endMood,
            context: moc
        )
        
        if success {
            // Update the songs array to reflect changes
            songs = mixTape.songsArray
            
            // Track interaction
            aiService.trackInteraction(
                type: "reordered_songs_\(startMood.rawValue)_to_\(endMood.rawValue)",
                mixtape: mixTape
            )
        } else {
            currentError = .aiServiceUnavailable
            retryAction = { smartReorderSongs(startMood: startMood, endMood: endMood) }
        }
        
        reorderInProgress = false
    }
    
    /// Play a specific song from the mixtape
    private func playSong(_ song: Song) {
        do {
            if self.currentMixTapeName != self.mixTape.wrappedTitle {
                self.currentMixTapeName = self.mixTape.wrappedTitle
                self.currentMixTapeImage = self.mixTape.wrappedUrl
            }
            
            let newPlayerItems = createArrayOfPlayerItems(songs: self.songs)
            if self.currentPlayerItems.items != newPlayerItems {
                self.currentPlayerItems.items = newPlayerItems
            }
            
            // Different behavior based on selection and current state
            if song == self.songs[0] && self.currentSongName.name == "Not Playing" {
                loadPlayer(arrayOfPlayerItems: self.currentPlayerItems.items, player: self.queuePlayer)
                
            } else if song != self.songs[0] && self.currentSongName.name == "Not Playing" {
                let index = Int(song.positionInTape)
                let slicedArray = self.currentPlayerItems.items[index...self.songs.count - 1]
                
                loadPlayer(arrayOfPlayerItems: Array(slicedArray), player: self.queuePlayer)
                
            } else if song == self.songs[0] && self.currentSongName.name != "Not Playing" {
                self.queuePlayer.pause()
                self.queuePlayer.currentItem?.seek(to: CMTime.zero, completionHandler: nil)
                
                loadPlayer(arrayOfPlayerItems: self.currentPlayerItems.items, player: self.queuePlayer)
                
            } else if song != self.songs[0] && self.currentSongName.name != "Not Playing" {
                self.queuePlayer.pause()
                self.queuePlayer.currentItem?.seek(to: CMTime.zero, completionHandler: nil)
                
                let index = Int(song.positionInTape)
                let slicedArray = self.currentPlayerItems.items[index...self.songs.count - 1]
                loadPlayer(arrayOfPlayerItems: Array(slicedArray), player: self.queuePlayer)
            }
            
            // Play and track interaction
            self.queuePlayer.play()
            
            // Update song play count
            song.trackPlay()
            mixTape.trackPlay()
            
            try moc.save()
            
            // Track interaction
            aiService.trackInteraction(type: "play_song", mixtape: mixTape)
            
            // Analyze audio for mood (simulated)
            aiService.detectMoodFromCurrentAudio(player: queuePlayer)
            
        } catch {
            currentError = AppError.audioLoadFailed(error)
            retryAction = { playSong(song) }
        }
    }
    
    private func songContextMenu(for song: Song) -> some View {
        Group {
            Button(action: {
                showingAIAnalysis = true
                aiService.trackInteraction(type: "analyze_song", mixtape: mixTape)
            }) {
                Label("Analyze with AI", systemImage: "waveform.path")
            }
            
            Button(action: {
                // Add to another mixtape
            }) {
                Label("Add to Mixtape", systemImage: "plus.rectangle.on.rectangle")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                deleteSongs(indexSet: IndexSet([songs.firstIndex(of: song)!]))
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// View for editing mood tags on a mixtape
struct MoodTagEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    var mixtape: MixTape
    var moc: NSManagedObjectContext
    @State private var selectedMoods: [Mood] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select moods that match this mixtape's vibe")
                    .font(.headline)
                    .padding(.top)
                
                // Grid of mood options
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        MoodTagToggle(
                            mood: mood,
                            isSelected: selectedMoods.contains(mood),
                            action: {
                                toggleMood(mood)
                            }
                        )
                    }
                }
                .padding()
                
                Spacer()
                
                // Apply button
                Button(action: {
                    saveMoodTags()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Apply Mood Tags")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom)
            .navigationBarTitle("Mood Tags", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                loadExistingTags()
            }
        }
    }
    
    /// Toggle a mood in the selection
    private func toggleMood(_ mood: Mood) {
        if let index = selectedMoods.firstIndex(of: mood) {
            selectedMoods.remove(at: index)
        } else {
            selectedMoods.append(mood)
        }
    }
    
    /// Load existing mood tags
    private func loadExistingTags() {
        let existingTags = mixtape.moodTagsArray
        
        selectedMoods = Mood.allCases.filter { mood in
            existingTags.contains(mood.rawValue)
        }
    }
    
    /// Save selected mood tags
    private func saveMoodTags() {
        // Convert selected moods to strings
        let moodStrings = selectedMoods.map { $0.rawValue }
        
        // Update mixtape
        mixtape.moodTags = moodStrings.joined(separator: ", ")
        
        // Save changes
        do {
            try moc.save()
        } catch {
            print("Error saving mood tags: \(error)")
        }
    }
}

/// Toggle button for mood tag selection
struct MoodTagToggle: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? mood.color : Color.gray.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: mood.systemIcon)
                        .foregroundColor(isSelected ? .white : mood.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mood.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? mood.color : .primary)
                    
                    Text(getMoodDescription(mood))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(mood.color)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? mood.color : Color.clear, lineWidth: 2)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            )
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    /// Get a short description for a mood
    private func getMoodDescription(_ mood: Mood) -> String {
        switch mood {
        case .energetic: return "Upbeat, vibrant tracks"
        case .relaxed: return "Calm, peaceful songs"
        case .happy: return "Joyful, positive tunes"
        case .melancholic: return "Reflective, emotional pieces"
        case .focused: return "Concentration-enhancing music"
        case .romantic: return "Love-themed, intimate songs"
        case .angry: return "Intense, powerful tracks"
        case .neutral: return "Balanced, versatile music"
        }
    }
}

/// View for displaying similar mixtapes
struct SimilarMixtapesView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: MixTape.entity(), sortDescriptors: [
        NSSortDescriptor(keyPath: \MixTape.title, ascending: true)
    ]) var allMixTapes: FetchedResults<MixTape>
    
    var originalMixtape: MixTape
    var aiService: AIIntegrationService
    
    @State private var similarityScores: [MixTape: Float] = [:]
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Analyzing mixtapes...")
                        .padding()
                } else {
                    if filteredMixtapes.isEmpty {
                        Text("No similar mixtapes found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        List {
                            ForEach(filteredMixtapes, id: \.wrappedTitle) { mixtape in
                                HStack {
                                    if mixtape.urlData != nil {
                                        Image(uiImage: getCoverArtImage(url: mixtape.wrappedUrl))
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
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mixtape.wrappedTitle)
                                            .font(.headline)
                                        
                                        Text("\(mixtape.numberOfSongs) songs")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Similarity percentage
                                    if let score = similarityScores[mixtape] {
                                        Text("\(Int(score * 100))% similar")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("Similar Mixtapes", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                calculateSimilarity()
            }
        }
    }
    
    /// List of filtered mixtapes (similar ones only)
    var filteredMixtapes: [MixTape] {
        let array = allMixTapes.filter { mixtape in
            // Don't include the original mixtape
            guard mixtape != originalMixtape else { return false }
            
            // Only include mixtapes with similarity score > 0.3
            if let score = similarityScores[mixtape], score > 0.3 {
                return true
            }
            return false
        }
        
        // Sort by similarity score (descending)
        return array.sorted { 
            similarityScores[$0] ?? 0 > similarityScores[$1] ?? 0
        }
    }
    
    /// Calculate similarity between mixtapes
    private func calculateSimilarity() {
        // Reset scores
        similarityScores = [:]
        
        // Set a small delay to show loading indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for mixtape in self.allMixTapes {
                // Skip the original mixtape
                if mixtape == self.originalMixtape { continue }
                
                // Calculate similarity score
                let score = self.calculateSimilarityScore(mixtape)
                self.similarityScores[mixtape] = score
            }
            
            // Finish loading
            self.isLoading = false
        }
    }
    
    /// Calculate similarity score between original mixtape and comparison mixtape
    private func calculateSimilarityScore(_ comparison: MixTape) -> Float {
        var score: Float = 0.0
        
        // Compare mood tags (highest impact)
        let originalTags = originalMixtape.moodTagsArray
        let comparisonTags = comparison.moodTagsArray
        
        let commonTags = Set(originalTags).intersection(Set(comparisonTags))
        if !originalTags.isEmpty && !comparisonTags.isEmpty {
            score += Float(commonTags.count) / Float(max(originalTags.count, comparisonTags.count)) * 0.5
        }
        
        // Compare song names (medium impact)
        let originalSongNames = originalMixtape.songsArray.map { $0.wrappedName.lowercased() }
        let comparisonSongNames = comparison.songsArray.map { $0.wrappedName.lowercased() }
        
        let commonWords = originalSongNames.joined(separator: " ").components(separatedBy: .whitespacesAndNewlines)
            .filter { word in
                word.count > 3 && comparisonSongNames.joined(separator: " ").contains(word)
            }
        
        score += min(Float(commonWords.count) * 0.05, 0.3)
        
        // Add randomization for demonstration
        score += Float.random(in: 0...0.2)
        
        // Cap at 1.0
        return min(score, 1.0)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(minWidth: 80)
        }
    }
}

struct MoodBadge: View {
    let mood: Mood
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: mood.systemIcon)
                    .font(.system(size: 12))
                Text(mood.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    Capsule()
                        .fill(mood.color.opacity(0.15))
                    
                    Capsule()
                        .strokeBorder(mood.color.opacity(0.3), lineWidth: 1)
                }
            )
            .foregroundColor(mood.color)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

struct SongRowView: View {
    let song: Song
    let isPlaying: Bool
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Play indicator or number
                ZStack {
                    if isPlaying {
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                    } else {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 36, height: 36)
                        
                        Text("\(songs.firstIndex(of: song)! + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Song info
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.wrappedTitle)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                    
                    Text(song.wrappedArtist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Duration and mood
                HStack(spacing: 12) {
                    if let mood = song.mood {
                        Circle()
                            .fill(Mood(rawValue: mood)?.color ?? .gray)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text(song.durationString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 45, alignment: .trailing)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isPlaying ? Color.accentColor.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
