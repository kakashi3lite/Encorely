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

/// Enhanced MixTapeView with AI features and improved accessibility
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
    
    // Dynamic Type support
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.colorScheme) var colorScheme
    
    // Current mood for theming
    private var currentMood: Mood {
        aiService.moodEngine.currentMood
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Mood tag badges at the top with improved accessibility
            if !getMoodTags().isEmpty {
                moodTagsSection
            }
            
            // Enhanced song list with mood theming
            songListView
            
            // AI-powered mixtape tools with improved layout
            aiToolsSection
        }
        .navigationBarTitle(mixTape.wrappedTitle, displayMode: .large)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarItems(trailing: EditButton())
        .dynamicTypeSize(.medium...accessibility3)
        .onAppear {
            // Track viewing of this mixtape
            aiService.trackInteraction(type: "view_mixtape", mixtape: mixTape)
            loadMoodTags()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mixtape: \(mixTape.wrappedTitle)")
    }
    
    // MARK: - Mood Tags Section
    
    private var moodTagsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(getMoodTags(), id: \.self) { tag in
                    if let mood = Mood(rawValue: tag) {
                        moodBadge(mood: mood)
                    } else {
                        genericMoodBadge(tag: tag)
                    }
                }
                
                // Edit mood tags button
                Button(action: {
                    showingMoodTagEditor = true
                    aiService.trackInteraction(type: "edit_mood_tags")
                }) {
                    Label("Edit mood tags", systemImage: "pencil.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Edit mood tags for this mixtape")
                .accessibilityHint("Double tap to modify mood classifications")
                .sheet(isPresented: $showingMoodTagEditor) {
                    MoodTagEditorView(mixtape: mixTape, moc: moc)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            Rectangle()
                .fill(currentMood.color.opacity(0.05))
                .ignoresSafeArea(.container, edges: .horizontal)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mood tags: \(getMoodTags().joined(separator: ", "))")
    }
    
    // MARK: - Song List View
    
    private var songListView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(songs, id: \.objectID) { song in
                    songRow(song: song)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(songRowBackground(for: song))
                                .shadow(
                                    color: currentMood.color.opacity(0.1),
                                    radius: 1,
                                    x: 0,
                                    y: 1
                                )
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)
                }
                .onDelete(perform: deleteSong)
                .onMove(perform: move)
            }
            .padding(.vertical, 8)
        }
    }
    
    private func songRow(song: Song) -> some View {
        Button(action: {
            playSong(song)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 12) {
                // Song position indicator
                Text("\(song.positionInTape + 1)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .center)
                    .accessibility(hidden: true)
                
                // Song name with improved typography
                Text(song.wrappedName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Mood indicator with accessibility
                if let moodTag = song.moodTag, let mood = Mood(rawValue: moodTag) {
                    Image(systemName: mood.systemIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(mood.color)
                        .frame(width: 20, height: 20)
                        .accessibilityLabel("Mood: \(mood.rawValue)")
                } else {
                    // Placeholder for alignment
                    Color.clear
                        .frame(width: 20, height: 20)
                }
                
                // Play indicator for current song
                if currentSongName.name.contains(song.wrappedName) && isPlaying.value {
                    Image(systemName: "speaker.wave.2.circle.fill")
                        .font(.caption)
                        .foregroundColor(currentMood.color)
                        .accessibilityLabel("Currently playing")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!checkSongUrlIsReachable(song: song))
        .opacity(checkSongUrlIsReachable(song: song) ? 1.0 : 0.6)
        .accessibilityLabel("Song \(song.positionInTape + 1): \(song.wrappedName)")
        .accessibilityHint("Double tap to play this song")
        .accessibilityAction(named: "Play") {
            playSong(song)
        }
        .onReceive(currentStatusObserver.$playerStatus) { status in
            isPlaying.value = getIsPlaying(status: status)
        }
    }
    
    private func songRowBackground(for song: Song) -> Color {
        if currentSongName.name.contains(song.wrappedName) {
            return currentMood.color.opacity(0.15)
        } else if let moodTag = song.moodTag, let mood = Mood(rawValue: moodTag) {
            return mood.color.opacity(0.05)
        } else {
            return Color.clear
        }
    }
    
    // MARK: - AI Tools Section
    
    private var aiToolsSection: some View {
        VStack(spacing: 0) {
            Divider()
                .background(currentMood.color.opacity(0.3))
            
            VStack(spacing: 16) {
                // Section header
                HStack {
                    Label("AI Tools", systemImage: "wand.and.stars")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(currentMood.color)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Tool buttons grid
                HStack(spacing: 20) {
                    // Smart reordering
                    aiToolButton(
                        icon: "arrow.up.arrow.down.circle.fill",
                        title: "Smart\nReorder",
                        action: {
                            showingSmartReorder = true
                            aiService.trackInteraction(type: "open_smart_reorder", mixtape: mixTape)
                        }
                    )
                    .actionSheet(isPresented: $showingSmartReorder) {
                        smartReorderActionSheet()
                    }
                    
                    // Find similar mixtapes
                    aiToolButton(
                        icon: "rectangle.stack.person.crop.fill",
                        title: "Find\nSimilar",
                        action: {
                            showingSimilarMixtapes = true
                            aiService.trackInteraction(type: "find_similar", mixtape: mixTape)
                        }
                    )
                    .sheet(isPresented: $showingSimilarMixtapes) {
                        SimilarMixtapesView(
                            originalMixtape: mixTape,
                            aiService: aiService
                        )
                    }
                    
                    // Add songs
                    aiToolButton(
                        icon: "plus.circle.fill",
                        title: "Add\nSongs",
                        action: {
                            showingDocsPicker.toggle()
                            aiService.trackInteraction(type: "add_songs", mixtape: mixTape)
                        }
                    )
                    .sheet(isPresented: $showingDocsPicker) {
                        MixTapeAdder(moc: moc, mixTapeToAddTo: mixTape, songs: $songs)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(
                Rectangle()
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: currentMood.color.opacity(0.1),
                        radius: 5,
                        x: 0,
                        y: -3
                    )
            )
        }
    }
    
    private func aiToolButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2.weight(.medium))
                    .foregroundColor(currentMood.color)
                    .frame(width: 32, height: 32)
                
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(currentMood.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(currentMood.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(title.replacingOccurrences(of: "\n", with: " "))
        .accessibilityHint("Double tap to use this AI tool")
    }
    
    // MARK: - Helper Views
    
    private func moodBadge(mood: Mood) -> some View {
        HStack(spacing: 6) {
            Image(systemName: mood.systemIcon)
                .font(.caption2.weight(.semibold))
            
            Text(mood.rawValue)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(mood.color.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(mood.color.opacity(0.5), lineWidth: 1)
                )
        )
        .foregroundColor(mood.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mood tag: \(mood.rawValue)")
    }
    
    private func genericMoodBadge(tag: String) -> some View {
        Text(tag)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.gray.opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(.secondary)
            .accessibilityLabel("Custom tag: \(tag)")
    }
    
    // MARK: - Helper Functions
    
    /// Action sheet for smart reordering options with enhanced accessibility
    private func smartReorderActionSheet() -> ActionSheet {
        ActionSheet(
            title: Text("Smart Reorder")
                .font(.headline.weight(.semibold)),
            message: Text("Let AI reorder your songs based on mood progression")
                .font(.subheadline),
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
        let success = mixTape.reorderSongsForMoodProgression(
            startMood: startMood,
            endMood: endMood,
            context: moc
        )
        
        if success {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                songs = mixTape.songsArray
            }
            
            // Haptic feedback for success
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            // Track interaction
            aiService.trackInteraction(
                type: "reordered_songs_\(startMood.rawValue)_to_\(endMood.rawValue)",
                mixtape: mixTape
            )
        } else {
            // Haptic feedback for failure
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    /// Play a specific song from the mixtape with improved UX
    private func playSong(_ song: Song) {
        // Haptic feedback for interaction
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        if currentMixTapeName != mixTape.wrappedTitle {
            currentMixTapeName = mixTape.wrappedTitle
            currentMixTapeImage = mixTape.wrappedUrl
        }
        
        let newPlayerItems = createArrayOfPlayerItems(songs: songs)
        if currentPlayerItems.items != newPlayerItems {
            currentPlayerItems.items = newPlayerItems
        }
        
        // Different behavior based on selection and current state
        let index = Int(song.positionInTape)
        
        if currentSongName.name == "Not Playing" {
            // Not currently playing
            if index == 0 {
                loadPlayer(arrayOfPlayerItems: currentPlayerItems.items, player: queuePlayer)
            } else {
                let slicedArray = Array(currentPlayerItems.items[index...])
                loadPlayer(arrayOfPlayerItems: slicedArray, player: queuePlayer)
            }
        } else {
            // Already playing
            queuePlayer.pause()
            queuePlayer.currentItem?.seek(to: CMTime.zero, completionHandler: nil)
            
            if index == 0 {
                loadPlayer(arrayOfPlayerItems: currentPlayerItems.items, player: queuePlayer)
            } else {
                let slicedArray = Array(currentPlayerItems.items[index...])
                loadPlayer(arrayOfPlayerItems: slicedArray, player: queuePlayer)
            }
        }
        
        // Play and track interaction
        queuePlayer.play()
        
        // Update counters
        song.trackPlay()
        mixTape.trackPlay()
        
        do {
            try moc.save()
        } catch {
            print("Error updating play counts: \(error)")
        }
        
        // Track interaction
        aiService.trackInteraction(type: "play_song", mixtape: mixTape)
        
        // Analyze audio for mood
        aiService.detectMoodFromCurrentAudio(player: queuePlayer)
    }
    
    /// Move songs with improved animation
    func move(from source: IndexSet, to destination: Int) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            songs.move(fromOffsets: source, toOffset: destination)
        }
        
        // Update positions
        var counter: Int16 = 0
        for song in songs {
            if song.positionInTape != counter {
                song.positionInTape = counter
            }
            counter += 1
        }
        
        // Notify of changes
        mixTape.willChangeValue(forKey: "songs")
        
        // Save changes
        do {
            try moc.save()
            aiService.trackInteraction(type: "manual_reorder", mixtape: mixTape)
            
            // Haptic feedback for success
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            print("Error saving reordered songs: \(error)")
            
            // Haptic feedback for error
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    /// Delete song with improved UX
    func deleteSong(offsets: IndexSet) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            for index in offsets.sorted(by: >) {
                let song = songs[index]
                moc.delete(song)
                songs.remove(at: index)
                
                // Track interaction
                aiService.trackInteraction(type: "delete_song", mixtape: mixTape)
            }
        }
        
        // Update song count and positions
        mixTape.numberOfSongs = Int16(songs.count)
        
        var counter: Int16 = 0
        for song in songs {
            if song.positionInTape != counter {
                song.positionInTape = counter
            }
            counter += 1
        }
        
        // Notify of changes
        mixTape.willChangeValue(forKey: "songs")
        
        do {
            try moc.save()
            
            // Haptic feedback for success
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            print("Error saving after deletion: \(error)")
            
            // Haptic feedback for error
            UINotificationFeedbackGenerator().notificationOccurred(.error)
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
}

// MARK: - Enhanced Mood Tag Editor

/// View for editing mood tags with improved accessibility
struct MoodTagEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    var mixtape: MixTape
    var moc: NSManagedObjectContext
    @State private var selectedMoods: [Mood] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header description
                    Text("Select moods that match this mixtape's vibe")
                        .font(.headline.weight(.medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Grid of mood options with improved layout
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2),
                        spacing: 16
                    ) {
                        ForEach(Mood.allCases, id: \.self) { mood in
                            MoodTagToggle(
                                mood: mood,
                                isSelected: selectedMoods.contains(mood),
                                action: {
                                    toggleMood(mood)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 32)
                    
                    // Apply button with mood-based styling
                    Button(action: {
                        saveMoodTags()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Apply Mood Tags (\(selectedMoods.count))")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        selectedMoods.isEmpty
                                            ? Color.gray
                                            : primaryMoodColor
                                    )
                            )
                    }
                    .disabled(selectedMoods.isEmpty)
                    .padding(.horizontal)
                    .accessibilityLabel("Apply \(selectedMoods.count) selected mood tags")
                    .accessibilityHint("Double tap to save mood selections")
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitle("Mood Tags", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .dynamicTypeSize(.medium...accessibility3)
            .onAppear {
                loadExistingTags()
            }
        }
    }
    
    private var primaryMoodColor: Color {
        selectedMoods.first?.color ?? .blue
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
        let moodStrings = selectedMoods.map { $0.rawValue }
        mixtape.moodTags = moodStrings.joined(separator: ", ")
        
        do {
            try moc.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("Error saving mood tags: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

/// Enhanced toggle button for mood tag selection
struct MoodTagToggle: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Mood icon with selection state
                ZStack {
                    Circle()
                        .fill(isSelected ? mood.color : mood.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(mood.color.opacity(0.5), lineWidth: isSelected ? 2 : 1)
                        )
                    
                    Image(systemName: mood.systemIcon)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(isSelected ? .white : mood.color)
                }
                
                // Mood name and description
                VStack(spacing: 4) {
                    Text(mood.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(isSelected ? mood.color : .primary)
                    
                    Text(getMoodShortDescription(mood))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(mood.color)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? mood.color : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: isSelected ? mood.color.opacity(0.3) : Color.black.opacity(0.05),
                        radius: 3,
                        x: 0,
                        y: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(mood.rawValue) mood")
        .accessibilityHint(isSelected ? "Selected. Double tap to deselect" : "Not selected. Double tap to select")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    /// Get a short description for a mood
    private func getMoodShortDescription(_ mood: Mood) -> String {
        switch mood {
        case .energetic: return "Upbeat, vibrant"
        case .relaxed: return "Calm, peaceful"
        case .happy: return "Joyful, positive"
        case .melancholic: return "Reflective, emotional"
        case .focused: return "Concentration-enhancing"
        case .romantic: return "Love-themed, intimate"
        case .angry: return "Intense, powerful"
        case .neutral: return "Balanced, versatile"
        }
    }
}

// MARK: - Enhanced Similar Mixtapes View

/// View for displaying similar mixtapes with improved accessibility
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
                    // Loading state with improved UX
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        
                        Text("Analyzing mixtapes...")
                            .font(.headline.weight(.medium))
                            .foregroundColor(.primary)
                        
                        Text("Finding mixtapes with similar vibes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Analyzing mixtapes to find similar ones")
                } else {
                    if filteredMixtapes.isEmpty {
                        // Empty state with suggestions
                        VStack(spacing: 20) {
                            Image(systemName: "magnifyingglass.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("No Similar Mixtapes Found")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            Text("Your \"\(originalMixtape.wrappedTitle)\" mixtape is unique! Try creating more mixtapes to find similarities.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(40)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("No similar mixtapes found. Your mixtape is unique.")
                    } else {
                        // Similar mixtapes list
                        List {
                            ForEach(filteredMixtapes, id: \.objectID) { mixtape in
                                similarMixtapeRow(mixtape: mixtape)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .padding(.vertical, 4)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .accessibilityLabel("List of similar mixtapes")
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
    
    private func similarMixtapeRow(mixtape: MixTape) -> some View {
        HStack(spacing: 16) {
            // Mixtape cover art
            if mixtape.urlData != nil {
                Image(uiImage: getCoverArtImage(url: mixtape.wrappedUrl))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                    )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            
            // Mixtape details
            VStack(alignment: .leading, spacing: 6) {
                Text(mixtape.wrappedTitle)
                    .font(.headline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(mixtape.numberOfSongs) songs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Mood tags if available
                if !mixtape.moodTagsArray.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(mixtape.moodTagsArray.prefix(3), id: \.self) { tag in
                                if let mood = Mood(rawValue: tag) {
                                    Text(mood.rawValue)
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(mood.color.opacity(0.2))
                                        )
                                        .foregroundColor(mood.color)
                                }
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            // Similarity percentage with visual indicator
            VStack(alignment: .trailing, spacing: 4) {
                if let score = similarityScores[mixtape] {
                    Text("\(Int(score * 100))%")
                        .font(.headline.weight(.bold))
                        .foregroundColor(similarityColor(for: score))
                    
                    Text("similar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // Similarity bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(similarityColor(for: score))
                                .frame(width: CGFloat(score) * geometry.size.width, height: 4)
                        }
                    }
                    .frame(width: 40, height: 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mixtape: \(mixtape.wrappedTitle), \(mixtape.numberOfSongs) songs, \(Int((similarityScores[mixtape] ?? 0) * 100))% similar")
    }
    
    private func similarityColor(for score: Float) -> Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        case 0.4..<0.6: return .yellow
        default: return .red
        }
    }
    
    /// List of filtered mixtapes (similar ones only)
    var filteredMixtapes: [MixTape] {
        let array = allMixTapes.filter { mixtape in
            guard mixtape != originalMixtape else { return false }
            
            if let score = similarityScores[mixtape], score > 0.3 {
                return true
            }
            return false
        }
        
        return array.sorted {
            similarityScores[$0] ?? 0 > similarityScores[$1] ?? 0
        }
    }
    
    /// Calculate similarity between mixtapes
    private func calculateSimilarity() {
        similarityScores = [:]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for mixtape in self.allMixTapes {
                if mixtape == self.originalMixtape { continue }
                
                let score = self.calculateSimilarityScore(mixtape)
                self.similarityScores[mixtape] = score
            }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                self.isLoading = false
            }
        }
    }
    
    /// Calculate similarity score between mixtapes
    private func calculateSimilarityScore(_ comparison: MixTape) -> Float {
        var score: Float = 0.0
        
        // Compare mood tags (highest impact)
        let originalTags = originalMixtape.moodTagsArray
        let comparisonTags = comparison.moodTagsArray
        
        let commonTags = Set(originalTags).intersection(Set(comparisonTags))
        if !originalTags.isEmpty && !comparisonTags.isEmpty {
            score += Float(commonTags.count) / Float(max(originalTags.count, comparisonTags.count)) * 0.5
        }
        
        // Compare song names for common words
        let originalSongNames = originalMixtape.songsArray.map { $0.wrappedName.lowercased() }
        let comparisonSongNames = comparison.songsArray.map { $0.wrappedName.lowercased() }
        
        let allOriginalWords = originalSongNames.joined(separator: " ").components(separatedBy: .whitespacesAndNewlines)
        let allComparisonWords = comparisonSongNames.joined(separator: " ").components(separatedBy: .whitespacesAndNewlines)
        
        let commonWords = Set(allOriginalWords).intersection(Set(allComparisonWords))
            .filter { $0.count > 3 } // Filter out short words
        
        score += min(Float(commonWords.count) * 0.05, 0.3)
        
        // Compare song counts (similar sized playlists might be more similar)
        let sizeDifference = abs(Float(originalMixtape.numberOfSongs - comparison.numberOfSongs))
        let maxSize = Float(max(originalMixtape.numberOfSongs, comparison.numberOfSongs))
        if maxSize > 0 {
            score += (1.0 - (sizeDifference / maxSize)) * 0.1
        }
        
        // Add a small random component for demonstration
        score += Float.random(in: 0...0.1)
        
        return min(score, 1.0)
    }
}