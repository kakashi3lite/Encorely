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

/// Enhanced MixTapeView with AI features
struct MixTapeView: View {
    // Core properties
    @Environment(\.managedObjectContext) var moc
    @State var songs: [Song]
    @State var mixTape: MixTape
    @Binding var currentMixTapeName: String
    @Binding var currentMixTapeImage: URL
    let queuePlayer: AVQueuePlayer
    let currentStatusObserver: PlayerStatusObserver
    let currentItemObserver: PlayerItemObserver
    @ObservedObject var currentPlayerItems: CurrentPlayerItems
    @ObservedObject var currentSongName: CurrentSongName
    @ObservedObject var isPlaying: IsPlaying
    
    // AI services
    var aiService: AIIntegrationService
    
    // State variables
    @State private var showingDocsPicker = false
    @State private var showingMoodTagEditor = false
    @State private var showingSmartReorder = false
    @State private var showingSimilarMixtapes = false
    @State private var selectedMoodTags: [String] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Mood tag badges at the top
            if !getMoodTags().isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(getMoodTags(), id: \.self) { tag in
                            if let mood = Mood(rawValue: tag) {
                                moodBadge(mood: mood)
                            } else {
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.gray.opacity(0.2)))
                            }
                        }
                        
                        Button(action: {
                            self.showingMoodTagEditor = true
                            aiService.trackInteraction(type: "edit_mood_tags")
                        }) {
                            Image(systemName: "pencil.circle")
                                .foregroundColor(.secondary)
                        }
                        .sheet(isPresented: $showingMoodTagEditor) {
                            MoodTagEditorView(mixtape: mixTape, moc: moc)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color.gray.opacity(0.05))
            }
            
            // Song list
            List { 
                ForEach(self.songs, id: \.positionInTape) { song in
                    Button(action: {
                        playSong(song)
                    }) {
                        HStack {
                            Text(song.wrappedName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Show mood icon if song has a mood
                            if let moodTag = song.moodTag, let mood = Mood(rawValue: moodTag) {
                                Image(systemName: mood.systemIcon)
                                    .foregroundColor(mood.color)
                            }
                        }
                        .contentShape(Rectangle())
                        .onReceive(self.currentStatusObserver.$playerStatus) { status in
                            self.isPlaying.value = getIsPlaying(status: status)
                        }
                    }
                    .disabled(!checkSongUrlIsReachable(song: song))
                }
                .onDelete(perform: deleteSong)
                .onMove(perform: move)
            }
            
            // AI-powered mixtape tools
            VStack(spacing: 12) {
                Divider()
                
                // AI organization tools
                HStack(spacing: 20) {
                    // Smart reordering
                    Button(action: {
                        self.showingSmartReorder = true
                        aiService.trackInteraction(type: "open_smart_reorder", mixtape: mixTape)
                    }) {
                        VStack {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 22))
                            Text("Smart Reorder")
                                .font(.caption)
                        }
                        .frame(minWidth: 80)
                    }
                    .actionSheet(isPresented: $showingSmartReorder) {
                        smartReorderActionSheet()
                    }
                    
                    // Find similar mixtapes
                    Button(action: {
                        self.showingSimilarMixtapes = true
                        aiService.trackInteraction(type: "find_similar", mixtape: mixTape)
                    }) {
                        VStack {
                            Image(systemName: "rectangle.stack.person.crop")
                                .font(.system(size: 22))
                            Text("Find Similar")
                                .font(.caption)
                        }
                        .frame(minWidth: 80)
                    }
                    .sheet(isPresented: $showingSimilarMixtapes) {
                        SimilarMixtapesView(
                            originalMixtape: mixTape,
                            aiService: aiService
                        )
                    }
                    
                    // Add songs
                    Button(action: {
                        self.showingDocsPicker.toggle()
                        aiService.trackInteraction(type: "add_songs", mixtape: mixTape)
                    }) {
                        VStack {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 22))
                            Text("Add Songs")
                                .font(.caption)
                        }
                        .frame(minWidth: 80)
                    }
                    .sheet(isPresented: self.$showingDocsPicker) {
                        MixTapeAdder(moc: self.moc, mixTapeToAddTo: self.mixTape, songs: self.$songs)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: -3)
        }
        .navigationBarTitle(self.mixTape.wrappedTitle)
        .navigationBarItems(
            trailing:
                Button(action: {}) {
                    EditButton()
                }
        )
        .onAppear {
            // Track viewing of this mixtape
            aiService.trackInteraction(type: "view_mixtape", mixtape: mixTape)
            
            // Load existing mood tags
            loadMoodTags()
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
                    reorderMixtape(startMood: .relaxed, endMood: .energetic)
                },
                .default(Text("Relaxing: Wind Down")) {
                    reorderMixtape(startMood: .energetic, endMood: .relaxed)
                },
                .default(Text("Focus: Start and Stay Focused")) {
                    reorderMixtape(startMood: .focused, endMood: .focused)
                },
                .default(Text("Happy Journey: Build to Joy")) {
                    reorderMixtape(startMood: .neutral, endMood: .happy)
                },
                .default(Text("Emotional Arc: Build and Release")) {
                    reorderMixtape(startMood: .melancholic, endMood: .relaxed)
                },
                .cancel()
            ]
        )
    }
    
    /// Reorder mixtape based on mood progression
    private func reorderMixtape(startMood: Mood, endMood: Mood) {
        // Call the mixtape's reorder method
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
        }
    }
    
    /// Play a specific song from the mixtape
    private func playSong(_ song: Song) {
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
        
        do {
            try moc.save()
        } catch {
            print("Error updating play counts: \(error)")
        }
        
        // Track interaction
        aiService.trackInteraction(type: "play_song", mixtape: mixTape)
        
        // Analyze audio for mood (simulated)
        aiService.detectMoodFromCurrentAudio(player: queuePlayer)
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
            print(error)
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
            print(error)
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
