import Testing
@testable import Encorely

/// Tests for MoodEngine's mood detection scoring logic.
struct MoodEngineTests {
    let engine = MoodEngine()

    // MARK: - Energetic Detection

    @Test("High energy + fast tempo + high danceability → energetic")
    func detectsEnergetic() {
        let features = AudioFeatures(
            tempo: 160, energy: 0.9, valence: 0.6,
            danceability: 0.85, acousticness: 0.1,
            instrumentalness: 0.2, speechiness: 0.1, liveness: 0.2
        )
        let result = engine.detectMood(from: features)
        #expect(result.mood == .energetic)
        #expect(result.confidence > 0.0)
    }

    // MARK: - Relaxed Detection

    @Test("Low energy + high acousticness + slow tempo → relaxed")
    func detectsRelaxed() {
        let features = AudioFeatures(
            tempo: 70, energy: 0.15, valence: 0.5,
            danceability: 0.2, acousticness: 0.9,
            instrumentalness: 0.5, speechiness: 0.05, liveness: 0.1
        )
        let result = engine.detectMood(from: features)
        #expect(result.mood == .relaxed)
    }

    // MARK: - Happy Detection

    @Test("High valence + moderate energy + danceability → happy")
    func detectsHappy() {
        let features = AudioFeatures(
            tempo: 120, energy: 0.7, valence: 0.95,
            danceability: 0.8, acousticness: 0.2,
            instrumentalness: 0.1, speechiness: 0.1, liveness: 0.2
        )
        let result = engine.detectMood(from: features)
        #expect(result.mood == .happy)
    }

    // MARK: - Melancholic Detection

    @Test("Low valence + low energy + acoustic → melancholic")
    func detectsMelancholic() {
        let features = AudioFeatures(
            tempo: 75, energy: 0.15, valence: 0.1,
            danceability: 0.15, acousticness: 0.85,
            instrumentalness: 0.3, speechiness: 0.05, liveness: 0.1
        )
        let result = engine.detectMood(from: features)
        #expect(result.mood == .melancholic)
    }

    // MARK: - Focused Detection

    @Test("High instrumentalness + low speechiness + mid energy → focused")
    func detectsFocused() {
        let features = AudioFeatures(
            tempo: 100, energy: 0.5, valence: 0.4,
            danceability: 0.3, acousticness: 0.4,
            instrumentalness: 0.95, speechiness: 0.02, liveness: 0.1
        )
        let result = engine.detectMood(from: features)
        #expect(result.mood == .focused)
    }

    // MARK: - Angry Detection

    @Test("High energy + low valence + fast tempo → angry")
    func detectsAngry() {
        let features = AudioFeatures(
            tempo: 170, energy: 0.95, valence: 0.05,
            danceability: 0.4, acousticness: 0.05,
            instrumentalness: 0.2, speechiness: 0.15, liveness: 0.3
        )
        let result = engine.detectMood(from: features)
        #expect(result.mood == .angry)
    }

    // MARK: - State Management

    @Test("Recent moods are tracked")
    func tracksRecentMoods() {
        // Use strongly polarized features so confidence passes threshold
        let features = AudioFeatures(
            tempo: 160, energy: 0.95, valence: 0.95,
            danceability: 0.9, acousticness: 0.05,
            instrumentalness: 0.1, speechiness: 0.05, liveness: 0.1
        )
        _ = engine.detectMood(from: features)
        #expect(!engine.recentMoods.isEmpty)
    }

    @Test("Reset clears state")
    func resetClearsState() {
        let features = AudioFeatures(
            tempo: 160, energy: 0.95, valence: 0.95,
            danceability: 0.9, acousticness: 0.05,
            instrumentalness: 0.1, speechiness: 0.05, liveness: 0.1
        )
        _ = engine.detectMood(from: features)
        engine.reset()
        #expect(engine.recentMoods.isEmpty)
        #expect(engine.moodConfidence == 0.0)
    }

    @Test("Preferred mood returns most frequent")
    func preferredMoodReturnsFrequent() {
        let features = AudioFeatures(
            tempo: 160, energy: 0.95, valence: 0.95,
            danceability: 0.9, acousticness: 0.05,
            instrumentalness: 0.1, speechiness: 0.05, liveness: 0.1
        )
        for _ in 0..<5 {
            _ = engine.detectMood(from: features)
        }
        let preferred = engine.preferredMood()
        #expect(preferred != nil)
    }

    // MARK: - Playlist Name

    @Test("Playlist name is non-empty")
    func playlistNameNotEmpty() {
        _ = engine.detectMood(from: AudioFeatures(energy: 0.5, valence: 0.5))
        let name = engine.suggestPlaylistName()
        #expect(!name.isEmpty)
    }
}
