import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var playerManager: PlayerManager
    @State private var showVolumeControl = false

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * playerManager.progress)
                    .frame(height: 2)
                    .animation(.linear(duration: 0.1), value: playerManager.progress)
            }
            .frame(height: 2)

            HStack(spacing: 16) {
                // Artwork
                playerManager.currentArtwork
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .cornerRadius(6)

                // Song info
                VStack(alignment: .leading, spacing: 2) {
                    Text(playerManager.currentSong?.title ?? "Not Playing")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(playerManager.currentSong?.artist ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Volume control (hidden by default)
                if showVolumeControl {
                    VolumeControl(
                        volume: $playerManager.volume,
                        showLabel: false,
                        size: 16,
                        onChanged: playerManager.setVolume
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                // Controls
                HStack(spacing: 20) {
                    Button(action: { withAnimation { showVolumeControl.toggle() } }) {
                        Image(systemName: playerManager.volumeIcon)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(playerManager.volumeLabel)

                    Button(action: playerManager.togglePlayPause) {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                    }
                    .accessibilityLabel(playerManager.isPlaying ? "Pause" : "Play")

                    Button(action: playerManager.skipToNext) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                    }
                    .accessibilityLabel("Next track")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Material.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.separator)),
                alignment: .top
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mini Player")
    }
}

// Extend PlayerManager with volume-related computed properties
extension PlayerManager {
    var volumeIcon: String {
        switch volume {
        case 0:
            "speaker.slash.fill"
        case 0 ..< 0.3:
            "speaker.wave.1.fill"
        case 0.3 ..< 0.7:
            "speaker.wave.2.fill"
        default:
            "speaker.wave.3.fill"
        }
    }

    var volumeLabel: String {
        switch volume {
        case 0:
            "Muted"
        case 0 ..< 0.3:
            "Low volume"
        case 0.3 ..< 0.7:
            "Medium volume"
        default:
            "High volume"
        }
    }
}
