import Testing
@testable import Encorely

/// Tests for RecommendationEngine's scoring and ranking logic.
struct RecommendationEngineTests {
    let moodEngine = MoodEngine()
    let personalityEngine = PersonalityEngine()

    var engine: RecommendationEngine {
        RecommendationEngine(moodEngine: moodEngine, personalityEngine: personalityEngine)
    }

    // MARK: - Helpers

    private func makeSong(
        name: String,
        energy: Float = 0.5,
        valence: Float = 0.5,
        tempo: Float = 120,
        danceability: Float = 0.5,
        acousticness: Float = 0.5,
        instrumentalness: Float = 0.3,
        speechiness: Float = 0.1,
        liveness: Float = 0.1
    ) -> Song {
        let song = Song(name: name, artist: "Test Artist", duration: 200)
        song.audioFeatures = AudioFeatures(
            tempo: tempo, energy: energy, valence: valence,
            danceability: danceability, acousticness: acousticness,
            instrumentalness: instrumentalness, speechiness: speechiness,
            liveness: liveness
        )
        return song
    }

    // MARK: - Tests

    @Test("Empty input returns empty results")
    func emptyInput() {
        let result = engine.recommend(songs: [], targetMood: .happy)
        #expect(result.isEmpty)
    }

    @Test("Songs without features are filtered out")
    func songsWithoutFeatures() {
        let song = Song(name: "No Features")
        let result = engine.recommend(songs: [song], targetMood: .happy)
        #expect(result.isEmpty)
    }

    @Test("Energetic mood ranks high-energy songs first")
    func energeticRanking() {
        let highEnergy = makeSong(name: "High", energy: 0.95, tempo: 160, danceability: 0.9)
        let lowEnergy = makeSong(name: "Low", energy: 0.1, tempo: 60, danceability: 0.1)
        let result = engine.recommend(songs: [lowEnergy, highEnergy], targetMood: .energetic)
        #expect(result.first?.name == "High")
    }

    @Test("Relaxed mood ranks low-energy acoustic songs first")
    func relaxedRanking() {
        let calm = makeSong(name: "Calm", energy: 0.1, tempo: 60, acousticness: 0.9)
        let loud = makeSong(name: "Loud", energy: 0.95, tempo: 160, acousticness: 0.05)
        let result = engine.recommend(songs: [loud, calm], targetMood: .relaxed)
        #expect(result.first?.name == "Calm")
    }

    @Test("Happy mood prefers high valence")
    func happyRanking() {
        let joyful = makeSong(name: "Joy", energy: 0.7, valence: 0.95, danceability: 0.8)
        let gloomy = makeSong(name: "Gloom", energy: 0.2, valence: 0.1, danceability: 0.2)
        let result = engine.recommend(songs: [gloomy, joyful], targetMood: .happy)
        #expect(result.first?.name == "Joy")
    }

    @Test("Limit parameter restricts output size")
    func limitWorks() {
        let songs = (0..<20).map { i in makeSong(name: "Song \(i)") }
        let result = engine.recommend(songs: songs, targetMood: .happy, limit: 5)
        #expect(result.count <= 5)
    }

    @Test("BuildMixtapeTrackList assigns positions and mood tags")
    func buildTrackList() {
        let songs = (0..<5).map { i in makeSong(name: "Track \(i)") }
        let tracks = engine.buildMixtapeTrackList(from: songs, mood: .focused, count: 3)
        #expect(tracks.count <= 3)
        for (index, track) in tracks.enumerated() {
            #expect(track.position == index)
            #expect(track.moodTag == "Focused")
        }
    }

    @Test("Cache invalidation resets cache")
    func cacheInvalidation() {
        let songs = [makeSong(name: "A")]
        _ = engine.recommend(songs: songs, targetMood: .happy)
        engine.invalidateCache()
        // After invalidation, a second call should recompute (no crash)
        let result = engine.recommend(songs: songs, targetMood: .happy)
        #expect(!result.isEmpty)
    }
}
