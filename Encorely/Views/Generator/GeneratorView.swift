import SwiftData
import SwiftUI

/// Generates a mixtape for the selected mood and shows progress.
struct GeneratorView: View {
    let targetMood: Mood

    @Environment(\.modelContext) private var modelContext
    @Environment(MoodEngine.self) private var moodEngine
    @Environment(RecommendationEngine.self) private var recommendationEngine
    @Environment(\.dismiss) private var dismiss

    @Query private var allSongs: [Song]

    @State private var generatedMixtape: Mixtape?
    @State private var isGenerating = false
    @State private var error: String?
    @State private var mixtapeTitle: String = ""

    var body: some View {
        VStack(spacing: 24) {
            if isGenerating {
                generatingView
            } else if let mixtape = generatedMixtape {
                successView(mixtape: mixtape)
            } else {
                configureView
            }
        }
        .padding()
        .navigationTitle("New Mixtape")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            mixtapeTitle = moodEngine.suggestPlaylistName()
        }
    }

    // MARK: - Configure

    private var configureView: some View {
        VStack(spacing: 20) {
            // Mood badge
            VStack(spacing: 8) {
                Image(systemName: targetMood.systemIcon)
                    .font(.system(size: 48))
                    .foregroundStyle(targetMood.color)
                Text(targetMood.rawValue)
                    .font(.title3.bold())
            }
            .padding(.top, 20)

            // Title field
            VStack(alignment: .leading, spacing: 6) {
                Text("Mixtape Name")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("Name your mixtape", text: $mixtapeTitle)
                    .textFieldStyle(.roundedBorder)
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            // Generate button
            Button {
                Task { await generate() }
            } label: {
                Label("Generate Mixtape", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(targetMood.color)
            .disabled(mixtapeTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Generating

    private var generatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Creating your \(targetMood.rawValue.lowercased()) mixtape...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Success

    private func successView(mixtape: Mixtape) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Mixtape Created!")
                .font(.title2.bold())

            Text("\"\(mixtape.title)\" with \(mixtape.songCount) songs")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            NavigationLink(value: AppDestination.mixtapeDetail(mixtapeID: mixtape.mixtapeID)) {
                Label("View Mixtape", systemImage: "music.note.list")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(targetMood.color)
        }
    }

    // MARK: - Logic

    @MainActor
    private func generate() async {
        isGenerating = true
        error = nil

        // Build track list from available songs
        let tracks = recommendationEngine.buildMixtapeTrackList(
            from: allSongs,
            mood: targetMood,
            count: 12
        )

        if tracks.isEmpty {
            // No songs with features available — create with empty list
            // In production, MusicKit search would supply songs
        }

        let mixtape = Mixtape(
            title: mixtapeTitle.trimmingCharacters(in: .whitespaces),
            isAIGenerated: true,
            moodTags: targetMood.rawValue
        )

        for (index, song) in tracks.enumerated() {
            let newSong = Song(
                name: song.name,
                artist: song.artist,
                appleMusicID: song.appleMusicID,
                position: index,
                duration: song.duration
            )
            newSong.moodTag = targetMood.rawValue
            newSong.audioFeaturesData = song.audioFeaturesData
            mixtape.songs.append(newSong)
        }

        modelContext.insert(mixtape)

        do {
            try modelContext.save()
            generatedMixtape = mixtape
        } catch {
            self.error = "Failed to save mixtape: \(error.localizedDescription)"
        }

        isGenerating = false
    }
}
