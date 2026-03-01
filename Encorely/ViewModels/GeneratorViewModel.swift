import Foundation
import Observation
import SwiftData

/// Manages the mixtape generation flow.
@Observable
final class GeneratorViewModel {
    var selectedMood: Mood?
    var mixtapeTitle: String = ""
    var isGenerating: Bool = false
    var generatedMixtape: Mixtape?
    var errorMessage: String?

    /// Generates a new mixtape using the recommendation engine.
    @MainActor
    func generate(
        mood: Mood,
        title: String,
        availableSongs: [Song],
        engine: RecommendationEngine,
        context: ModelContext
    ) {
        isGenerating = true
        errorMessage = nil

        let tracks = engine.buildMixtapeTrackList(from: availableSongs, mood: mood, count: 12)

        let mixtape = Mixtape(title: title, isAIGenerated: true, moodTags: mood.rawValue)
        for (index, song) in tracks.enumerated() {
            let newSong = Song(
                name: song.name,
                artist: song.artist,
                appleMusicID: song.appleMusicID,
                position: index,
                duration: song.duration
            )
            newSong.moodTag = mood.rawValue
            newSong.audioFeaturesData = song.audioFeaturesData
            mixtape.songs.append(newSong)
        }

        context.insert(mixtape)
        do {
            try context.save()
            generatedMixtape = mixtape
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }
}
