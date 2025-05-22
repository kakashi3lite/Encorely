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

/// Enhanced MixTapeView with AI features and error handling
struct MixTapeView: View {
    // Core properties
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
    
    // State
    @State private var showingDocsPicker = false
    @State private var showingSmartReorder = false
    @State private var showingSimilarMixtapes = false
    @State private var showingAIAnalysis = false
    @State private var selectedMoodTags: [String] = []
    @State private var isAnalyzing = false
    @State private var reorderInProgress = false
    @State private var retryAction: (() -> Void)?
    @State private var currentError: AppError?
    
    var body: some View {
        VStack(spacing: 0) {
            // Error banner if needed
            if let error = currentError {
                ErrorBanner(error: error) {
                    retryAction?()
                }
            }
            
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Mood tag badges
                    if !getMoodTags().isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(getMoodTags(), id: \.self) { tag in
                                    if let mood = Mood(rawValue: tag) {
                                        MoodBadge(mood: mood) {
                                            selectedMoodTags.contains(tag) ?
                                                selectedMoodTags.removeAll { $0 == tag } :
                                                selectedMoodTags.append(tag)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Action buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            // Smart Reorder
                            ActionButton(
                                icon: "wand.and.stars",
                                title: "Smart Reorder",
                                action: { showingSmartReorder = true }
                            )
                            
                            // Find Similar
                            ActionButton(
                                icon: "rectangle.stack.person.crop",
                                title: "Find Similar",
                                action: {
                                    showingSimilarMixtapes = true
                                    aiService.trackInteraction(type: "find_similar", mixtape: mixTape)
                                }
                            )
                            
                            // Add Songs
                            ActionButton(
                                icon: "plus.circle",
                                title: "Add Songs",
                                action: {
                                    showingDocsPicker = true
                                    aiService.trackInteraction(type: "add_songs", mixtape: mixTape)
                                }
                            )
                            
                            // AI Analysis
                            ActionButton(
                                icon: "chart.bar.xaxis",
                                title: "AI Analysis",
                                action: {
                                    showingAIAnalysis = true
                                    aiService.trackInteraction(type: "view_analysis", mixtape: mixTape)
                                }
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // Songs list
                    VStack(spacing: 2) {
                        ForEach(songs) { song in
                            SongRowView(
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
                .padding(.vertical)
            }
            
            // Playback controls
            if let currentSong = songs.first(where: { $0.title == currentSongName.wrappedValue }) {
                PlaybackControlsView(
                    song: currentSong,
                    isPlaying: isPlaying,
                    onPlayPause: togglePlayback,
                    onNext: playNextSong,
                    onPrevious: playPreviousSong
                )
                .transition(.move(edge: .bottom))
            }
        }
        .navigationBarTitle(mixTape.wrappedTitle)
        .navigationBarItems(trailing: EditButton())
        .background(Color(.systemGroupedBackground))
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
    }
    
    // MARK: - Supporting Views
    
    struct SongRowView: View {
        let song: Song
        let isPlaying: Bool
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Play indicator or song number
                    if isPlaying {
                        Image(systemName: "music.note")
                            .foregroundColor(.accentColor)
                    }
                    
                    // Song info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.wrappedTitle)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(song.wrappedArtist)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Duration and mood
                    HStack(spacing: 8) {
                        if let mood = song.mood {
                            Circle()
                                .fill(Mood(rawValue: mood)?.color ?? .gray)
                                .frame(width: 8, height: 8)
                        }
                        
                        Text(song.durationString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(isPlaying ? Color.accentColor.opacity(0.1) : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    struct ActionButton: View {
        let icon: String
        let title: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                    Text(title)
                        .font(.caption)
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
                HStack(spacing: 4) {
                    Image(systemName: mood.systemIcon)
                        .font(.caption)
                    Text(mood.rawValue)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(mood.color.opacity(0.2)))
                .foregroundColor(mood.color)
            }
        }
    }
    
    struct PlaybackControlsView: View {
        let song: Song
        let isPlaying: Bool
        let onPlayPause: () -> Void
        let onNext: () -> Void
        let onPrevious: () -> Void
        
        var body: some View {
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 20) {
                    // Song info
                    VStack(alignment: .leading) {
                        Text(song.wrappedTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(song.wrappedArtist)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Playback controls
                    HStack(spacing: 24) {
                        Button(action: onPrevious) {
                            Image(systemName: "backward.fill")
                                .font(.title3)
                        }
                        
                        Button(action: onPlayPause) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }
                        
                        Button(action: onNext) {
                            Image(systemName: "forward.fill")
                                .font(.title3)
                        }
                    }
                    .foregroundColor(.primary)
                }
                .padding()
                .background(
                    Rectangle()
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: -3)
                )
            }
        }
    }
    
    // MARK: - Helper Functions
    
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
    
    /// Move songs within the mixtape
    func move(from source: IndexSet, to destination: Int) {
        // Standard reordering code
        self.songs.move(fromOffsets: source, toOffset: destination)
        
        // Update song's positionInTape property
        var counter: Int16 = 0
        for song in self.songs {
            if song.positionInTape != counter {
                 song.positionInTape = counter
            }
            counter += 1
        }
        
        // Notify mixtape of changes to songs
        self.mixTape.willChangeValue(forKey: "songs")
        
        // Save changes
        do {
            try self.moc.save()
            aiService.trackInteraction(type: "manual_reorder", mixtape: mixTape)
        } catch {
            currentError = AppError.saveFailure(error)
            retryAction = { move(from: source, to: destination) }
        }
    }
    
    /// Delete a song from the mixtape
    func deleteSong(offsets: IndexSet) {
        for index in offsets {
            let song = self.songs[index]
            moc.delete(song)
            self.songs.remove(at: index)
            
            // Track interaction
            aiService.trackInteraction(type: "delete_song", mixtape: mixTape)
        }
        
        self.mixTape.numberOfSongs = Int16(self.songs.count)
        
        // Update song's positionInTape property
        var counter: Int16 = 0
        for song in self.songs {
            if song.positionInTape != counter {
                   song.positionInTape = counter
            }
            counter += 1
        }
        
        // Notify mixtape of changes to songs
        self.mixTape.willChangeValue(forKey: "songs")
        
        do {
            try moc.save()
        } catch {
            currentError = AppError.deletionFailure(error)
            // No retry for deletion as it would be confusing
        }
    }
    
    /// Get mood tags from the mixtape
    private func getMoodTags() -> [String] {
        return mixTape.moodTagsArray
    }
    
    /// Load mood tags from mixtape
    private func loadMoodTags() {
        selectedMoodTags = getMoodTags()
    }
    
    /// Create a mood badge view
    private func moodBadge(mood: Mood) -> some View {
        HStack(spacing: 4) {
            Image(systemName: mood.systemIcon)
                .font(.system(size: 12))
            
            Text(mood.rawValue)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(mood.color.opacity(0.2)))
        .foregroundColor(mood.color)
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
