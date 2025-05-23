import SwiftUI
import AVKit

struct PlayerView: View {
    // MARK: - Properties
    
    @Environment(\.presentationMode) var presentationMode
    @Binding var currentMixTapeName: String
    @Binding var currentMixTapeImage: URL
    
    let queuePlayer: AVQueuePlayer
    let currentStatusObserver: PlayerStatusObserver
    let currentItemObserver: PlayerItemObserver
    let currentPlayerItems: CurrentPlayerItems
    let currentSongName: CurrentSongName
    let isPlaying: IsPlaying
    let aiService: AIIntegrationService
    
    @State private var showingLyrics = false
    @State private var volume: Double = 0.5
    @State private var isShuffleOn = false
    @State private var repeatMode: RepeatMode = .off
    @State private var progress: Double = 0
    @State private var duration: Double = 0
    @State private var currentTime: String = "0:00"
    @State private var totalTime: String = "0:00"
    
    enum RepeatMode {
        case off, all, one
        
        var icon: String {
            switch self {
            case .off: return "repeat"
            case .all: return "repeat"
            case .one: return "repeat.1"
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Album art / visualization
                ZStack {
                    // Background gradient
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    aiService.moodEngine.currentMood.color.opacity(0.8),
                                    aiService.personalityEngine.currentPersonality.themeColor.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 300)
                    
                    // Visualization orbs
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .offset(y: isPlaying.wrappedValue ? -20 : 0)
                            .animation(
                                Animation
                                    .easeInOut(duration: 0.8)
                                    .repeatForever()
                                    .delay(Double(i) * 0.2),
                                value: isPlaying.wrappedValue
                            )
                    }
                }
                .padding(.horizontal)
                
                // Song info
                VStack(spacing: 8) {
                    Text(currentSongName.wrappedValue ?? "Not Playing")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(currentMixTapeName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Progress bar
                VStack(spacing: 8) {
                    Slider(value: $progress)
                        .accentColor(aiService.moodEngine.currentMood.color)
                    
                    HStack {
                        Text(currentTime)
                        Spacer()
                        Text(totalTime)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Playback controls
                HStack(spacing: 32) {
                    Button(action: toggleShuffle) {
                        Image(systemName: "shuffle")
                            .font(.title3)
                            .foregroundColor(isShuffleOn ? .accentColor : .primary)
                    }
                    
                    Button(action: previousTrack) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                    }
                    
                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying.wrappedValue ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(aiService.moodEngine.currentMood.color)
                    }
                    
                    Button(action: nextTrack) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }
                    
                    Button(action: cycleRepeatMode) {
                        Image(systemName: repeatMode.icon)
                            .font(.title3)
                            .foregroundColor(repeatMode != .off ? .accentColor : .primary)
                    }
                }
                
                // Volume slider
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(.secondary)
                    
                    Slider(value: $volume)
                        .accentColor(.secondary)
                    
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Additional controls
                HStack(spacing: 40) {
                    Button(action: { showingLyrics.toggle() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "text.quote")
                                .font(.title3)
                            Text("Lyrics")
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        // Add to playlist
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus.rectangle.on.rectangle")
                                .font(.title3)
                            Text("Add to")
                                .font(.caption)
                        }
                    }
                    
                    ShareLink(item: "Check out this song!") {
                        VStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                            Text("Share")
                                .font(.caption)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            .padding(.vertical)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.down")
                            .imageScale(.large)
                    }
                }
            }
            .sheet(isPresented: $showingLyrics) {
                LyricsView(song: currentSongName.wrappedValue ?? "")
            }
        }
    }
    
    // MARK: - Actions
    
    private func togglePlayback() {
        if isPlaying.wrappedValue {
            queuePlayer.pause()
        } else {
            queuePlayer.play()
        }
    }
    
    private func previousTrack() {
        queuePlayer.seek(to: .zero)
        if let items = currentPlayerItems.items {
            if let currentItem = queuePlayer.currentItem,
               let currentIndex = items.firstIndex(of: currentItem),
               currentIndex > 0 {
                queuePlayer.replaceCurrentItem(with: items[currentIndex - 1])
            }
        }
    }
    
    private func nextTrack() {
        if let items = currentPlayerItems.items {
            if let currentItem = queuePlayer.currentItem,
               let currentIndex = items.firstIndex(of: currentItem),
               currentIndex < items.count - 1 {
                queuePlayer.replaceCurrentItem(with: items[currentIndex + 1])
            }
        }
    }
    
    private func toggleShuffle() {
        isShuffleOn.toggle()
        // Implement shuffle logic
    }
    
    private func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
        // Implement repeat logic
    }
}

// MARK: - Supporting Views

struct LyricsView: View {
    let song: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Lyrics coming soon...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding()
            }
            .navigationTitle("Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
