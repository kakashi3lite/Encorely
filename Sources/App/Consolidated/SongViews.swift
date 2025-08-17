import SwiftUI

// MARK: - Song Row Views

struct SongRowView: View {
    let song: Song
    let isPlaying: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Play indicator or song number
                if isPlaying {
                    Image(systemName: "music.note")
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                }

                // Song info
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.wrappedName)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(song.wrappedArtist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Duration and mood
                HStack(spacing: 8) {
                    if let mood = song.mood {
                        Circle()
                            .fill(Mood(rawValue: mood)?.color ?? .gray)
                            .frame(width: 8, height: 8)
                    }

                    Text(song.durationString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SongGridCell: View {
    let song: Song
    let isPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Cover art or placeholder
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fit)
                        .cornerRadius(8)

                    if isPlaying {
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundColor(.accentColor)
                    } else {
                        Image(systemName: "music.note")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.wrappedName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(song.wrappedArtist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 4)

                if let mood = song.mood {
                    HStack {
                        Circle()
                            .fill(Mood(rawValue: mood)?.color ?? .gray)
                            .frame(width: 6, height: 6)
                        Text(mood)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CompactSongRow: View {
    let song: Song
    let isPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if isPlaying {
                    Image(systemName: "play.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 16)
                }

                Text(song.wrappedName)
                    .lineLimit(1)

                Spacer()

                Text(song.durationString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Transitions and Modifiers

extension View {
    func horizontalSlideTransition(isVisible: Bool) -> some View {
        transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
    }
}
