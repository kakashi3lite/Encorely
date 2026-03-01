import SwiftUI

/// Compact player bar shown above the tab bar when a song is playing.
struct MiniPlayerView: View {
    @Environment(AudioPlaybackService.self) private var playbackService
    @Environment(MoodEngine.self) private var moodEngine
    @State private var showingFullPlayer = false

    var body: some View {
        Button {
            showingFullPlayer = true
        } label: {
            HStack(spacing: 12) {
                // Mood-colored mini artwork
                RoundedRectangle(cornerRadius: 6)
                    .fill(moodEngine.currentMood.color.gradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: moodEngine.currentMood.systemIcon)
                            .font(.caption)
                            .foregroundStyle(.white)
                    }

                // Song info
                VStack(alignment: .leading, spacing: 2) {
                    Text(playbackService.currentSong?.name ?? "Not Playing")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(playbackService.currentSong?.artist ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Play/pause
                Button {
                    playbackService.togglePlayPause()
                } label: {
                    Image(systemName: playbackService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .accessibilityLabel(playbackService.isPlaying ? "Pause" : "Play")

                // Skip
                Button {
                    playbackService.skipForward()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                }
                .accessibilityLabel("Next")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .sheet(isPresented: $showingFullPlayer) {
            PlayerView()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now playing: \(playbackService.currentSong?.name ?? "nothing")")
        .accessibilityHint("Double tap to open full player")
    }
}
