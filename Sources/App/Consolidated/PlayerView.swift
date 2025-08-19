import AVKit
import SwiftUI
import DesignSystem

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
            case .off: "repeat"
            case .all: "repeat"
            case .one: "repeat.1"
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
                    GlassCard {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        aiService.moodEngine.currentMood.color.opacity(0.6),
                                        aiService.personalityEngine.currentPersonality.themeColor.opacity(0.6),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 300)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(aiService.moodEngine.currentMood.color.opacity(0.25), lineWidth: 1)
                            )
                    }

                    // Visualization orbs
                    ForEach(0 ..< 3) { i in
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
                .accessibilityHidden(true) // Hide visualization from VoiceOver

                // Song info
                GlassCard {
                    VStack(spacing: 8) {
                        Text(currentSongName.wrappedValue ?? "Not Playing")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(NoirPalette.onGlass)

                        Text(currentMixTapeName)
                            .font(.subheadline)
                            .foregroundColor(NoirPalette.subduedText)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Now playing")
                .accessibilityValue("\(currentSongName.wrappedValue ?? "Not Playing") from \(currentMixTapeName)")
                .accessibilityAddTraits(.updatesFrequently)

                // Progress bar
                GlassCard {
                    VStack(spacing: 8) {
                        Slider(value: $progress)
                            .tint(aiService.moodEngine.currentMood.color)
                        .accessibilityLabel("Playback progress")
                        .accessibilityValue("\(currentTime) of \(totalTime)")
                        .accessibilityHint("Adjust to seek through the song")

                        HStack {
                            Text(currentTime)
                                .accessibilityHidden(true)
                            Spacer()
                            Text(totalTime)
                                .accessibilityHidden(true)
                        }
                        .font(.caption)
                        .foregroundColor(NoirPalette.subduedText)
                    }
                }

                // Player controls
                GlassCard {
                    HStack(spacing: 40) {
                    // Previous
                    Button(action: previousTrack) {
                        Image(systemName: "backward.fill")
                            .font(.title)
                    }
                    .accessibilityLabel("Previous track")
                    .accessibilityHint("Play previous song")

                    // Play/Pause
                    Button(action: playPause) {
                        Image(systemName: isPlaying.wrappedValue ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(LinearGradient(colors: [aiService.moodEngine.currentMood.color, aiService.personalityEngine.currentPersonality.themeColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .accessibilityLabel(isPlaying.wrappedValue ? "Pause" : "Play")
                    .accessibilityHint(isPlaying.wrappedValue ? "Pause current song" : "Play current song")
                    .accessibilityAddTraits(isPlaying.wrappedValue ? .startsMediaSession : .playsSound)

                    // Next
                    Button(action: nextTrack) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                    }
                    .accessibilityLabel("Next track")
                    .accessibilityHint("Play next song")
                    }
                }

                // Volume and playlist controls
                GlassCard {
                    HStack(spacing: 20) {
                    // Volume slider
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(NoirPalette.subduedText)
                            .accessibilityHidden(true)

                        Slider(value: $volume)
                            .accessibilityLabel("Volume")
                            .accessibilityValue("\(Int(volume * 100))%")
                            .accessibilityHint("Adjust volume")

                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(NoirPalette.subduedText)
                            .accessibilityHidden(true)
                    }

                    // Shuffle
                    Button(action: toggleShuffle) {
                        Image(systemName: "shuffle")
                            .foregroundColor(isShuffleOn ? aiService.moodEngine.currentMood.color : NoirPalette.subduedText)
                    }
                    .accessibilityLabel("Shuffle")
                    .accessibilityValue(isShuffleOn ? "On" : "Off")
                    .accessibilityHint("Toggle shuffle play")
                    .accessibilityAddTraits(isShuffleOn ? .isSelected : [])

                    // Repeat
                    Button(action: cycleRepeatMode) {
                        Image(systemName: repeatMode.icon)
                            .foregroundColor(repeatMode != .off ? aiService.moodEngine.currentMood.color : NoirPalette.subduedText)
                    }
                    .accessibilityLabel("Repeat mode")
                    .accessibilityValue(repeatModeDescription)
                    .accessibilityHint("Change repeat mode")
                    }
                }
            }
            .padding()
            .background(NoirPalette.background.ignoresSafeArea())
        }
    }

    // Computed property for repeat mode description
    private var repeatModeDescription: String {
        switch repeatMode {
        case .off: "Off"
        case .all: "Repeat all"
        case .one: "Repeat one"
        }
    }

    // MARK: - Control Functions

    private func playPause() {
        if isPlaying.wrappedValue {
            queuePlayer.pause()
            aiService.trackInteraction(type: "pause")
        } else {
            queuePlayer.play()
            aiService.trackInteraction(type: "play")
        }
    }

    private func previousTrack() {
        queuePlayer.seek(to: .zero)
        if let previous = currentPlayerItems.items.first(where: { $0.title == currentSongName.wrappedValue }) {
            queuePlayer.seek(to: .zero, completionHandler: nil)
        }
        aiService.trackInteraction(type: "previous_track")
    }

    private func nextTrack() {
        queuePlayer.advanceToNextItem()
        aiService.trackInteraction(type: "next_track")
    }

    private func toggleShuffle() {
        isShuffleOn.toggle()
        aiService.trackInteraction(type: "toggle_shuffle_\(isShuffleOn ? "on" : "off")")
    }

    private func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
        aiService.trackInteraction(type: "change_repeat_mode_\(repeatMode)")
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
