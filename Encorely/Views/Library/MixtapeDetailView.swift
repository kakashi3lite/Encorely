import SwiftData
import SwiftUI

/// Shows all songs in a mixtape with playback controls.
struct MixtapeDetailView: View {
    let mixtapeID: String

    @Query private var allMixtapes: [Mixtape]
    @Environment(AudioPlaybackService.self) private var playbackService
    @Environment(\.modelContext) private var modelContext

    private var mixtape: Mixtape? {
        allMixtapes.first { $0.mixtapeID == mixtapeID }
    }

    var body: some View {
        Group {
            if let mixtape {
                content(for: mixtape)
            } else {
                ErrorView(
                    title: "Mixtape Not Found",
                    message: "This mixtape may have been deleted.",
                    retryAction: nil
                )
            }
        }
        .navigationTitle(mixtape?.title ?? "Mixtape")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func content(for mixtape: Mixtape) -> some View {
        List {
            // Header section
            Section {
                headerView(for: mixtape)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            // Songs section
            Section("Songs") {
                ForEach(Array(mixtape.songs.sorted(by: { $0.position < $1.position }).enumerated()), id: \.element.songID) { index, song in
                    songRow(song: song, index: index, in: mixtape)
                }
            }
        }
        .listStyle(.plain)
    }

    private func headerView(for mixtape: Mixtape) -> some View {
        VStack(spacing: 16) {
            // Mood color banner
            RoundedRectangle(cornerRadius: 16)
                .fill(mixtape.dominantMood.color.gradient)
                .frame(height: 120)
                .overlay {
                    VStack {
                        Image(systemName: mixtape.dominantMood.systemIcon)
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                        Text(mixtape.dominantMood.rawValue)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }

            // Play all button
            Button {
                playbackService.play(songs: mixtape.songs.sorted(by: { $0.position < $1.position }))
            } label: {
                Label("Play All", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(mixtape.dominantMood.color)

            // Stats
            HStack {
                Label("\(mixtape.songCount) songs", systemImage: "music.note")
                Spacer()
                Label("\(mixtape.playCount) plays", systemImage: "play.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func songRow(song: Song, index: Int, in mixtape: Mixtape) -> some View {
        Button {
            playbackService.play(
                songs: mixtape.songs.sorted(by: { $0.position < $1.position }),
                startingAt: index
            )
        } label: {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(.body)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let tag = song.moodTag {
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (Mood(rawValue: tag)?.color ?? .gray).opacity(0.2),
                            in: Capsule()
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(song.name) by \(song.artist)")
    }
}
