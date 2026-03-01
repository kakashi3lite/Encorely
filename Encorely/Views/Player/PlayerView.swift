import SwiftUI

/// Full-screen now-playing view with album art, controls, and visualization.
struct PlayerView: View {
    @Environment(AudioPlaybackService.self) private var playbackService
    @Environment(MoodEngine.self) private var moodEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Spacer()

            // Artwork
            artworkView
                .padding(.horizontal, 40)

            Spacer()

            // Song info
            songInfoView
                .padding(.horizontal, 24)

            // Progress bar
            progressView
                .padding(.horizontal, 24)
                .padding(.top, 16)

            // Controls
            controlsView
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Spacer()
        }
        .background(
            moodEngine.currentMood.color.opacity(0.15)
                .ignoresSafeArea()
        )
    }

    // MARK: - Artwork

    private var artworkView: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                (playbackService.currentSong != nil
                    ? moodEngine.currentMood.color
                    : Color.gray
                ).gradient
            )
            .aspectRatio(1, contentMode: .fit)
            .shadow(radius: 16, y: 8)
            .overlay {
                Image(systemName: moodEngine.currentMood.systemIcon)
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .accessibilityHidden(true)
    }

    // MARK: - Song Info

    private var songInfoView: some View {
        VStack(spacing: 4) {
            Text(playbackService.currentSong?.name ?? "Not Playing")
                .font(.title3.bold())
                .lineLimit(1)

            Text(playbackService.currentSong?.artist ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Progress

    private var progressView: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { playbackService.progress },
                    set: { playbackService.seek(toProgress: $0) }
                ),
                in: 0...1
            )
            .tint(moodEngine.currentMood.color)

            HStack {
                Text(formatTime(playbackService.currentTime))
                Spacer()
                Text("-\(formatTime(playbackService.duration - playbackService.currentTime))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Playback progress, \(Int(playbackService.progress * 100)) percent")
    }

    // MARK: - Controls

    private var controlsView: some View {
        HStack(spacing: 40) {
            Button { playbackService.skipBackward() } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Previous")

            Button { playbackService.togglePlayPause() } label: {
                Image(systemName: playbackService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
            }
            .accessibilityLabel(playbackService.isPlaying ? "Pause" : "Play")

            Button { playbackService.skipForward() } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Next")
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
