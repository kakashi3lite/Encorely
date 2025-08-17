//
//  DiscoverView.swift
//  AI Mixtapes
//
//  Created by AI Assistant on 2024
//  Copyright © 2024 AI Mixtapes. All rights reserved.
//

import SwiftUI
import MusicKit

struct DiscoverView: View {
    // MARK: - Environment Objects
    @EnvironmentObject private var mixtapeStore: MixtapeStore
    @EnvironmentObject private var musicAuthorizationManager: MusicAuthorizationManager
    
    // MARK: - State
    @State private var selectedMood: Mood = .neutral
    @State private var showingMoodSelector = false
    @State private var searchText = ""
    @State private var recommendedSongs: [Song] = []
    @State private var isLoadingRecommendations = false
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    moodSelectorSection
                    recentMixtapesSection
                    recommendationsSection
                    Spacer(minLength: 100)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Discover")
            .searchable(text: $searchText, prompt: "Search for music...")
            .refreshable {
                await loadRecommendations()
            }
        }
        .onAppear {
            loadInitialData()
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Good \(timeOfDayGreeting)!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("What's your mood today?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { showingMoodSelector = true }) {
                    HStack {
                        Text(selectedMood.emoji)
                        Text(selectedMood.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedMood.color.opacity(0.2))
                    .foregroundColor(selectedMood.color)
                    .cornerRadius(16)
                }
            }
        }
        .padding(.top)
    }
    
    private var moodSelectorSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    MoodCard(mood: mood, isSelected: mood == selectedMood) {
                        selectedMood = mood
                        Task {
                            await loadRecommendations()
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var recentMixtapesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Mixtapes")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink("See All", destination: MixtapesView())
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            
            if mixtapeStore.mixtapes.isEmpty {
                EmptyStateView(
                    title: "No mixtapes yet",
                    subtitle: "Generate your first AI mixtape",
                    systemImage: "music.note.list"
                )
                .frame(height: 120)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(mixtapeStore.recentMixtapes()) { mixtape in
                            MixtapeCard(mixtape: mixtape) {
                                mixtapeStore.setCurrentMixtape(mixtape)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recommended for \(selectedMood.displayName)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isLoadingRecommendations {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if recommendedSongs.isEmpty && !isLoadingRecommendations {
                EmptyStateView(
                    title: "No recommendations",
                    subtitle: "Try selecting a different mood",
                    systemImage: "music.note"
                )
                .frame(height: 120)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recommendedSongs) { song in
                        SongRow(song: song) {
                            // Handle song selection
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "morning"
        case 12..<17:
            return "afternoon"
        case 17..<22:
            return "evening"
        default:
            return "night"
        }
    }
    
    private func loadInitialData() {
        Task {
            await loadRecommendations()
        }
    }
    
    private func loadRecommendations() async {
        guard musicAuthorizationManager.canPlayMusic else { return }
        
        isLoadingRecommendations = true
        
        // Simulate loading recommendations
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // In a real app, this would fetch from MusicKit or AI service
        let mockSongs = [
            Song(id: "1", title: "Sample Song 1", artist: "Artist 1", duration: 180),
            Song(id: "2", title: "Sample Song 2", artist: "Artist 2", duration: 210),
            Song(id: "3", title: "Sample Song 3", artist: "Artist 3", duration: 195)
        ]
        
        await MainActor.run {
            self.recommendedSongs = mockSongs
            self.isLoadingRecommendations = false
        }
    }
}

// MARK: - Supporting Views

struct MoodCard: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(mood.emoji)
                    .font(.title2)
                
                Text(mood.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? mood.color.opacity(0.3) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? mood.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MixtapeCard: View {
    let mixtape: Mixtape
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(mixtape.mood.color.gradient)
                    .frame(width: 120, height: 120)
                    .overlay {
                        VStack {
                            Text(mixtape.mood.emoji)
                                .font(.title)
                            Text("\(mixtape.songCount) songs")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mixtape.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    Text(mixtape.formattedDuration)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SongRow: View {
    let song: Song
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(song.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(song.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button {
                    // Add to mixtape action
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview
#Preview {
    DiscoverView()
        .environmentObject(MixtapeStore.preview)
        .environmentObject(MusicAuthorizationManager.preview)
}