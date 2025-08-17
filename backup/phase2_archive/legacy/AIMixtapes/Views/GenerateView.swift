//
//  GenerateView.swift
//  AI Mixtapes
//
//  Created by AI Assistant on 2024
//  Copyright © 2024 AI Mixtapes. All rights reserved.
//

import SwiftUI
import MusicKit

struct GenerateView: View {
    // MARK: - Environment Objects
    @EnvironmentObject private var mixtapeStore: MixtapeStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var musicAuthorizationManager: MusicAuthorizationManager
    
    // MARK: - State
    @State private var selectedMood: Mood = .neutral
    @State private var mixtapeName = ""
    @State private var selectedGenres: Set<String> = []
    @State private var selectedArtists: Set<String> = []
    @State private var songCount: Double = 15
    @State private var includeExplicit = false
    @State private var energyLevel: Double = 0.5
    @State private var danceability: Double = 0.5
    @State private var valence: Double = 0.5
    @State private var showingAdvancedOptions = false
    @State private var isGenerating = false
    @State private var generationProgress: Double = 0.0
    @State private var currentStep = ""
    
    // MARK: - Constants
    private let availableGenres = [
        "Pop", "Rock", "Hip-Hop", "R&B", "Electronic", "Jazz", "Classical",
        "Country", "Folk", "Indie", "Alternative", "Reggae", "Blues", "Funk"
    ]
    
    private let popularArtists = [
        "Taylor Swift", "Drake", "The Weeknd", "Billie Eilish", "Ed Sheeran",
        "Ariana Grande", "Post Malone", "Dua Lipa", "Harry Styles", "Olivia Rodrigo"
    ]
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    moodSelectionSection
                    basicOptionsSection
                    genreSelectionSection
                    artistSelectionSection
                    
                    if showingAdvancedOptions {
                        advancedOptionsSection
                    }
                    
                    advancedToggleSection
                    generateButtonSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Generate Mixtape")
            .navigationBarTitleDisplayMode(.large)
            .disabled(isGenerating)
            .overlay {
                if isGenerating {
                    generationOverlay
                }
            }
        }
        .onAppear {
            setupDefaultValues()
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            
            Text("Create Your Perfect Mixtape")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Tell us your mood and preferences, and our AI will craft a personalized mixtape just for you.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    private var moodSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's your mood?")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    MoodSelectionCard(mood: mood, isSelected: mood == selectedMood) {
                        selectedMood = mood
                        updateMoodBasedDefaults()
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var basicOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Options")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Mixtape Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mixtape Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter a name (optional)", text: $mixtapeName)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Song Count
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Number of Songs")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(Int(songCount))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $songCount, in: 5...50, step: 1)
                        .accentColor(selectedMood.color)
                }
                
                // Include Explicit
                Toggle("Include explicit content", isOn: $includeExplicit)
                    .font(.subheadline)
            }
        }
    }
    
    private var genreSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferred Genres (Optional)")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Select up to 3 genres to influence your mixtape")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(availableGenres, id: \.self) { genre in
                    GenreChip(genre: genre, isSelected: selectedGenres.contains(genre)) {
                        toggleGenreSelection(genre)
                    }
                }
            }
        }
    }
    
    private var artistSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Favorite Artists (Optional)")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Select artists you'd like to hear more of")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(popularArtists, id: \.self) { artist in
                    ArtistChip(artist: artist, isSelected: selectedArtists.contains(artist)) {
                        toggleArtistSelection(artist)
                    }
                }
            }
        }
    }
    
    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced Audio Features")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 20) {
                // Energy Level
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Energy Level")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(energyLevelDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $energyLevel, in: 0...1)
                        .accentColor(selectedMood.color)
                }
                
                // Danceability
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Danceability")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(danceabilityDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $danceability, in: 0...1)
                        .accentColor(selectedMood.color)
                }
                
                // Valence (Positivity)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Positivity")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(valenceDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $valence, in: 0...1)
                        .accentColor(selectedMood.color)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var advancedToggleSection: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingAdvancedOptions.toggle()
            }
        } label: {
            HStack {
                Text("Advanced Options")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: showingAdvancedOptions ? "chevron.up" : "chevron.down")
                    .font(.caption)
            }
            .foregroundColor(.accentColor)
        }
    }
    
    private var generateButtonSection: some View {
        VStack(spacing: 16) {
            Button {
                generateMixtape()
            } label: {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    
                    Text(isGenerating ? "Generating..." : "Generate Mixtape")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(selectedMood.color.gradient)
                .foregroundColor(.white)
                .cornerRadius(25)
            }
            .disabled(isGenerating || !musicAuthorizationManager.canPlayMusic)
            
            if !musicAuthorizationManager.canPlayMusic {
                Text("Apple Music authorization required")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var generationOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    ProgressView(value: generationProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: selectedMood.color))
                        .frame(width: 200)
                    
                    Text(currentStep)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .background(.regularMaterial)
                .cornerRadius(20)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var energyLevelDescription: String {
        switch energyLevel {
        case 0..<0.3: return "Calm"
        case 0.3..<0.7: return "Moderate"
        default: return "High Energy"
        }
    }
    
    private var danceabilityDescription: String {
        switch danceability {
        case 0..<0.3: return "Chill"
        case 0.3..<0.7: return "Groovy"
        default: return "Dance"
        }
    }
    
    private var valenceDescription: String {
        switch valence {
        case 0..<0.3: return "Melancholic"
        case 0.3..<0.7: return "Neutral"
        default: return "Upbeat"
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultValues() {
        if mixtapeName.isEmpty {
            mixtapeName = generateDefaultName()
        }
        updateMoodBasedDefaults()
    }
    
    private func generateDefaultName() -> String {
        let timeOfDay = Calendar.current.component(.hour, from: Date())
        let timeString = timeOfDay < 12 ? "Morning" : timeOfDay < 17 ? "Afternoon" : "Evening"
        return "\(timeString) \(selectedMood.displayName) Mix"
    }
    
    private func updateMoodBasedDefaults() {
        switch selectedMood {
        case .happy, .excited:
            energyLevel = 0.8
            danceability = 0.7
            valence = 0.9
        case .sad, .melancholic:
            energyLevel = 0.3
            danceability = 0.2
            valence = 0.2
        case .angry:
            energyLevel = 0.9
            danceability = 0.5
            valence = 0.3
        case .calm, .peaceful:
            energyLevel = 0.2
            danceability = 0.3
            valence = 0.6
        case .energetic:
            energyLevel = 0.9
            danceability = 0.8
            valence = 0.7
        case .romantic:
            energyLevel = 0.4
            danceability = 0.4
            valence = 0.7
        case .nostalgic:
            energyLevel = 0.5
            danceability = 0.4
            valence = 0.5
        case .focused:
            energyLevel = 0.6
            danceability = 0.3
            valence = 0.6
        case .neutral:
            energyLevel = 0.5
            danceability = 0.5
            valence = 0.5
        }
    }
    
    private func toggleGenreSelection(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.remove(genre)
        } else if selectedGenres.count < 3 {
            selectedGenres.insert(genre)
        }
    }
    
    private func toggleArtistSelection(_ artist: String) {
        if selectedArtists.contains(artist) {
            selectedArtists.remove(artist)
        } else if selectedArtists.count < 5 {
            selectedArtists.insert(artist)
        }
    }
    
    private func generateMixtape() {
        guard !isGenerating else { return }
        
        isGenerating = true
        generationProgress = 0.0
        
        let preferences = MixtapePreferences(
            mood: selectedMood,
            genres: Array(selectedGenres),
            artists: Array(selectedArtists),
            songCount: Int(songCount),
            includeExplicit: includeExplicit,
            energyLevel: energyLevel,
            danceability: danceability,
            valence: valence
        )
        
        Task {
            await mixtapeStore.generateMixtape(
                name: mixtapeName.isEmpty ? generateDefaultName() : mixtapeName,
                preferences: preferences
            ) { step, progress in
                await MainActor.run {
                    self.currentStep = step
                    self.generationProgress = progress
                }
            }
            
            await MainActor.run {
                self.isGenerating = false
            }
        }
    }
}

// MARK: - Supporting Views

struct MoodSelectionCard: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(mood.emoji)
                    .font(.title)
                
                Text(mood.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? mood.color.opacity(0.3) : Color(.systemGray5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? mood.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GenreChip: View {
    let genre: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(genre)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .accentColor : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ArtistChip: View {
    let artist: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(artist)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .accentColor : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    GenerateView()
        .environmentObject(MixtapeStore.preview)
        .environmentObject(AppState())
        .environmentObject(MusicAuthorizationManager.preview)
}