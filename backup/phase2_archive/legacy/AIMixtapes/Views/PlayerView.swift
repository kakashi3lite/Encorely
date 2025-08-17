//
//  PlayerView.swift
//  AI Mixtapes
//
//  Created by AI Assistant on 2024
//  Copyright © 2024 AI Mixtapes. All rights reserved.
//

import SwiftUI
import MusicKit
import AVFoundation

struct PlayerView: View {
    // MARK: - Environment Objects
    @EnvironmentObject private var mixtapeStore: MixtapeStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var musicAuthorizationManager: MusicAuthorizationManager
    
    // MARK: - State
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var volume: Float = 0.7
    @State private var isShuffled = false
    @State private var repeatMode: RepeatMode = .off
    @State private var showingQueue = false
    @State private var showingLyrics = false
    @State private var currentSongIndex = 0
    @State private var isLiked = false
    @State private var showingShareSheet = false
    
    // MARK: - Computed Properties
    private var currentMixtape: Mixtape? {
        mixtapeStore.currentMixtape
    }
    
    private var currentSong: Song? {
        guard let mixtape = currentMixtape,
              currentSongIndex < mixtape.songs.count else {
            return nil
        }
        return mixtape.songs[currentSongIndex]
    }
    
    private var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let mixtape = currentMixtape, let song = currentSong {
                    playerContent(mixtape: mixtape, song: song)
                } else {
                    emptyPlayerView
                }
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        playerMenu
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingQueue) {
            QueueView(currentIndex: $currentSongIndex)
        }
        .sheet(isPresented: $showingLyrics) {
            LyricsView(song: currentSong)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let song = currentSong {
                ShareSheet(song: song)
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func playerContent(mixtape: Mixtape, song: Song) -> some View {
        ScrollView {
            VStack(spacing: 32) {
                // Album Artwork
                albumArtworkSection(mixtape: mixtape)
                
                // Song Info
                songInfoSection(song: song)
                
                // Progress Bar
                progressSection
                
                // Main Controls
                mainControlsSection
                
                // Secondary Controls
                secondaryControlsSection
                
                // Mixtape Info
                mixtapeInfoSection(mixtape: mixtape)
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func albumArtworkSection(mixtape: Mixtape) -> some View {
        VStack(spacing: 16) {
            // Main artwork
            RoundedRectangle(cornerRadius: 20)
                .fill(mixtape.mood.color.gradient)
                .frame(width: 280, height: 280)
                .overlay {
                    VStack(spacing: 12) {
                        Text(mixtape.mood.emoji)
                            .font(.system(size: 60))
                        
                        Text(mixtape.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .shadow(color: mixtape.mood.color.opacity(0.3), radius: 20, x: 0, y: 10)
            
            // Visualizer
            AudioVisualizerView(isPlaying: isPlaying, color: mixtape.mood.color)
                .frame(height: 60)
        }
    }
    
    private func songInfoSection(song: Song) -> some View {
        VStack(spacing: 8) {
            Text(song.title)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text(song.artist)
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(currentMixtape?.mood.color ?? .accentColor)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newProgress = value.location.x / UIScreen.main.bounds.width
                        currentTime = duration * Double(max(0, min(1, newProgress)))
                    }
            )
            
            // Time labels
            HStack {
                Text(formatTime(currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatTime(duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var mainControlsSection: some View {
        HStack(spacing: 40) {
            // Previous
            Button(action: previousSong) {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .foregroundColor(.primary)
            }
            .disabled(currentSongIndex == 0 && repeatMode != .all)
            
            // Play/Pause
            Button(action: togglePlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(currentMixtape?.mood.color ?? .accentColor)
            }
            
            // Next
            Button(action: nextSong) {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .foregroundColor(.primary)
            }
            .disabled(currentSongIndex == (currentMixtape?.songs.count ?? 0) - 1 && repeatMode != .all)
        }
    }
    
    private var secondaryControlsSection: some View {
        HStack(spacing: 32) {
            // Like
            Button(action: toggleLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundColor(isLiked ? .red : .secondary)
            }
            
            // Shuffle
            Button(action: toggleShuffle) {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundColor(isShuffled ? (currentMixtape?.mood.color ?? .accentColor) : .secondary)
            }
            
            // Repeat
            Button(action: toggleRepeat) {
                Image(systemName: repeatMode.iconName)
                    .font(.title3)
                    .foregroundColor(repeatMode != .off ? (currentMixtape?.mood.color ?? .accentColor) : .secondary)
            }
            
            // Volume
            HStack {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: $volume, in: 0...1)
                    .frame(width: 80)
                    .accentColor(currentMixtape?.mood.color ?? .accentColor)
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func mixtapeInfoSection(mixtape: Mixtape) -> some View {
        VStack(spacing: 16) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("From Mixtape")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(mixtape.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Text("\(currentSongIndex + 1) of \(mixtape.songs.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var emptyPlayerView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Music Playing")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Select a mixtape to start listening")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            NavigationLink("Browse Mixtapes", destination: MixtapesView())
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var playerMenu: some View {
        Group {
            Button("Show Queue") {
                showingQueue = true
            }
            
            Button("Show Lyrics") {
                showingLyrics = true
            }
            
            Button("Share Song") {
                showingShareSheet = true
            }
            
            Divider()
            
            Button("Add to Library") {
                // Add current song to user's library
            }
            
            Button("Create Station") {
                // Create radio station based on current song
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func togglePlayPause() {
        isPlaying.toggle()
        // In a real app, this would control actual playback
    }
    
    private func previousSong() {
        if currentSongIndex > 0 {
            currentSongIndex -= 1
            resetPlayback()
        } else if repeatMode == .all {
            currentSongIndex = (currentMixtape?.songs.count ?? 1) - 1
            resetPlayback()
        }
    }
    
    private func nextSong() {
        if currentSongIndex < (currentMixtape?.songs.count ?? 0) - 1 {
            currentSongIndex += 1
            resetPlayback()
        } else if repeatMode == .all {
            currentSongIndex = 0
            resetPlayback()
        } else if repeatMode == .one {
            resetPlayback()
        }
    }
    
    private func resetPlayback() {
        currentTime = 0
        duration = currentSong?.duration ?? 0
        // In a real app, this would reset the audio player
    }
    
    private func toggleShuffle() {
        isShuffled.toggle()
        // In a real app, this would shuffle the queue
    }
    
    private func toggleRepeat() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
    }
    
    private func toggleLike() {
        isLiked.toggle()
        // In a real app, this would save to user's liked songs
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Types

enum RepeatMode: CaseIterable {
    case off, all, one
    
    var iconName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

// MARK: - Supporting Views

struct AudioVisualizerView: View {
    let isPlaying: Bool
    let color: Color
    
    @State private var animationValues: [Double] = Array(repeating: 0.1, count: 20)
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color.opacity(0.7))
                    .frame(width: 3)
                    .scaleEffect(y: animationValues[index])
                    .animation(
                        .easeInOut(duration: Double.random(in: 0.3...0.8))
                        .repeatForever(autoreverses: true),
                        value: animationValues[index]
                    )
            }
        }
        .onAppear {
            startAnimation()
        }
        .onChange(of: isPlaying) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func startAnimation() {
        guard isPlaying else { return }
        
        for index in 0..<20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                animationValues[index] = Double.random(in: 0.2...1.0)
            }
        }
    }
    
    private func stopAnimation() {
        for index in 0..<20 {
            animationValues[index] = 0.1
        }
    }
}

struct QueueView: View {
    @Binding var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var mixtapeStore: MixtapeStore
    
    var body: some View {
        NavigationView {
            List {
                if let mixtape = mixtapeStore.currentMixtape {
                    ForEach(Array(mixtape.songs.enumerated()), id: \.element.id) { index, song in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(song.title)
                                    .fontWeight(index == currentIndex ? .semibold : .regular)
                                Text(song.artist)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if index == currentIndex {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.caption)
                            }
                            
                            Text(song.formattedDuration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            currentIndex = index
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Up Next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LyricsView: View {
    let song: Song?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let song = song {
                        Text(song.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(song.artist)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        Text("Lyrics not available")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ShareSheet: View {
    let song: Song
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Share \"\(song.title)\" by \(song.artist)")
                .padding()
            
            Button("Done") {
                dismiss()
            }
            .padding()
        }
    }
}

// MARK: - Preview
#Preview {
    PlayerView()
        .environmentObject(MixtapeStore.preview)
        .environmentObject(AppState())
        .environmentObject(MusicAuthorizationManager.preview)
}

#Preview("Empty State") {
    PlayerView()
        .environmentObject(MixtapeStore())
        .environmentObject(AppState())
        .environmentObject(MusicAuthorizationManager.preview)
}