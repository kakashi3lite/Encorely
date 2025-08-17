import AVKit
import SwiftUI

struct MiniPlayerView: View {
    let queuePlayer: AVQueuePlayer
    @ObservedObject var currentSongName: CurrentSongName
    @ObservedObject var isPlaying: IsPlaying
    @Binding var showingFullPlayer: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Cover art / placeholder
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)

                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            .accessibilityHidden(true) // Hide art from VoiceOver since it's decorative

            // Song info
            VStack(alignment: .leading, spacing: 2) {
                Text(currentSongName.wrappedValue ?? "Not Playing")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text("Now Playing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Now playing: \(currentSongName.wrappedValue ?? "Not Playing")")

            Spacer()

            // Controls
            HStack(spacing: 24) {
                Button(action: {
                    if isPlaying.wrappedValue {
                        queuePlayer.pause()
                    } else {
                        queuePlayer.play()
                    }
                }) {
                    Image(systemName: isPlaying.wrappedValue ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                }
                .accessibilityLabel(isPlaying.wrappedValue ? "Pause" : "Play")
                .accessibilityHint(isPlaying.wrappedValue ? "Pause current song" : "Play current song")

                Button(action: {
                    showingFullPlayer = true
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
                .accessibilityLabel("More options")
                .accessibilityHint("Open full player view")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5))
        .onTapGesture {
            showingFullPlayer = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
