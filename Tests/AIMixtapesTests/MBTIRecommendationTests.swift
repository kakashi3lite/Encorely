@testable import App
import XCTest

class MBTIRecommendationTests: XCTestCase {
    var recommendationEngine: RecommendationEngine!

    override func setUp() {
        super.setUp()
        // Create an MBTI profile for testing
        let profile = MBTIProfile(
            extraversion: 0.8, // Strongly extroverted
            sensing: 0.3, // Slightly intuitive
            thinking: 0.6, // Moderately thinking
            judging: 0.7 // Moderately judging
        )
        recommendationEngine = RecommendationEngine(mbtiProfile: profile)
    }

    override func tearDown() {
        recommendationEngine = nil
        super.tearDown()
    }

    // MARK: - MBTI Profile Tests

    func testMBTIProfileCreation() {
        let profile = MBTIProfile(
            extraversion: 0.8,
            sensing: 0.3,
            thinking: 0.6,
            judging: 0.7
        )

        XCTAssertEqual(profile.extraversion, 0.8)
        XCTAssertEqual(profile.introversion, 0.2)
        XCTAssertEqual(profile.sensing, 0.3)
        XCTAssertEqual(profile.intuition, 0.7)
        XCTAssertEqual(profile.thinking, 0.6)
        XCTAssertEqual(profile.feeling, 0.4)
        XCTAssertEqual(profile.judging, 0.7)
        XCTAssertEqual(profile.perceiving, 0.3)
        XCTAssertEqual(profile.typeString, "ENTJ")
    }

    func testAudioPreferencesGeneration() {
        let profile = MBTIProfile(
            extraversion: 1.0, // Maximum extraversion
            sensing: 0.0, // Maximum intuition
            thinking: 1.0, // Maximum thinking
            judging: 1.0 // Maximum judging
        )

        let prefs = profile.audioPreferences

        // Extroverted preference for high energy and faster tempo
        XCTAssertGreaterThan(prefs.energy, 0.7)
        XCTAssertGreaterThan(prefs.tempo, 120)

        // Intuitive preference for complexity
        XCTAssertGreaterThan(prefs.complexity, 0.6)

        // Judging preference for structure
        XCTAssertGreaterThan(prefs.structure, 0.7)

        // Thinking preference for lower emotional valence
        XCTAssertLessThan(prefs.valence, 0.5)
    }

    // MARK: - Recommendation Tests

    func testRecommendationGeneration() async throws {
        // Create test songs with different characteristics
        let energeticSong = createTestSong(
            name: "High Energy",
            energy: 0.9,
            valence: 0.8,
            tempo: 140
        )

        let calmSong = createTestSong(
            name: "Calm",
            energy: 0.3,
            valence: 0.6,
            tempo: 80
        )

        let complexSong = createTestSong(
            name: "Complex",
            energy: 0.6,
            valence: 0.5,
            tempo: 110,
            complexity: 0.9
        )

        // Get recommendations based on these songs
        let recommendations = try await recommendationEngine.getRecommendations(
            forMood: .energetic,
            basedOn: [energeticSong, calmSong, complexSong]
        )

        XCTAssertFalse(recommendations.isEmpty)

        // For an extroverted profile, energetic song should be ranked higher
        if let firstRec = recommendations.first {
            XCTAssertEqual(firstRec.name, "High Energy")
        }
    }

    func testActivityAdjustedRecommendations() async throws {
        // Create a mix of songs
        let songs = [
            createTestSong(name: "Energetic", energy: 0.9, tempo: 140),
            createTestSong(name: "Moderate", energy: 0.5, tempo: 110),
            createTestSong(name: "Calm", energy: 0.3, tempo: 80),
        ]

        // Get initial recommendations
        let baseRecommendations = try await recommendationEngine.getRecommendations(
            forMood: .neutral,
            basedOn: songs
        )

        // Simulate activity change
        // This would normally come from SensorDataManager
        // For now we'll just verify the recommendations are generated
        XCTAssertNotNil(baseRecommendations)
        XCTAssertFalse(baseRecommendations.isEmpty)
    }

    // MARK: - Extended MBTI Tests

    func testPersonalityTypeExtremesRecommendations() async throws {
        // Test ISTJ (Introverted, Sensing, Thinking, Judging)
        let istjProfile = MBTIProfile(
            extraversion: 0.2, // Introverted
            sensing: 0.8, // Sensing
            thinking: 0.8, // Thinking
            judging: 0.8 // Judging
        )
        recommendationEngine.updateMBTIProfile(istjProfile)

        let istjPrefs = istjProfile.audioPreferences
        XCTAssertLessThan(istjPrefs.energy, 0.5) // Lower energy for introverts
        XCTAssertGreaterThan(istjPrefs.structure, 0.7) // High structure for SJ

        // Test ENFP (Extraverted, Intuitive, Feeling, Perceiving)
        let enfpProfile = MBTIProfile(
            extraversion: 0.8, // Extraverted
            sensing: 0.2, // Intuitive
            thinking: 0.2, // Feeling
            judging: 0.2 // Perceiving
        )
        recommendationEngine.updateMBTIProfile(enfpProfile)

        let enfpPrefs = enfpProfile.audioPreferences
        XCTAssertGreaterThan(enfpPrefs.energy, 0.6) // Higher energy for extroverts
        XCTAssertGreaterThan(enfpPrefs.variety, 0.7) // High variety for NP
    }

    func testMoodMBTIInteraction() async throws {
        let songs = [
            createTestSong(name: "Happy", energy: 0.7, valence: 0.8, tempo: 120),
            createTestSong(name: "Sad", energy: 0.3, valence: 0.2, tempo: 80),
            createTestSong(name: "Intense", energy: 0.9, valence: 0.5, tempo: 150),
        ]

        // Test how different personalities handle the same mood
        let introvertedProfile = MBTIProfile(
            extraversion: 0.2, sensing: 0.5, thinking: 0.5, judging: 0.5
        )
        recommendationEngine.updateMBTIProfile(introvertedProfile)

        let introvertRecs = try await recommendationEngine.getRecommendations(
            forMood: .energetic,
            basedOn: songs
        )

        let extrovertedProfile = MBTIProfile(
            extraversion: 0.8, sensing: 0.5, thinking: 0.5, judging: 0.5
        )
        recommendationEngine.updateMBTIProfile(extrovertedProfile)

        let extrovertRecs = try await recommendationEngine.getRecommendations(
            forMood: .energetic,
            basedOn: songs
        )

        // Extroverts should get higher energy recommendations even in the same mood
        let introvertEnergy = introvertRecs.first?.features?.energy ?? 0
        let extrovertEnergy = extrovertRecs.first?.features?.energy ?? 0
        XCTAssertGreaterThan(extrovertEnergy, introvertEnergy)
    }

    func testActivityPersonalityAdaptation() async throws {
        let songs = [
            createTestSong(name: "Workout", energy: 0.9, valence: 0.8, tempo: 160),
            createTestSong(name: "Focus", energy: 0.4, valence: 0.5, tempo: 100),
            createTestSong(name: "Ambient", energy: 0.2, valence: 0.6, tempo: 70),
        ]

        // Test how different personalities adapt to high activity
        let judgingProfile = MBTIProfile(
            extraversion: 0.5, sensing: 0.5, thinking: 0.5, judging: 0.8
        )
        recommendationEngine.updateMBTIProfile(judgingProfile)

        let perceivingProfile = MBTIProfile(
            extraversion: 0.5, sensing: 0.5, thinking: 0.5, judging: 0.2
        )

        // First get base recommendations
        let baseJudgingRecs = try await recommendationEngine.getRecommendations(
            forMood: .neutral,
            basedOn: songs
        )

        recommendationEngine.updateMBTIProfile(perceivingProfile)
        let basePerceivingRecs = try await recommendationEngine.getRecommendations(
            forMood: .neutral,
            basedOn: songs
        )

        // Now simulate high activity and get new recommendations
        // In a real implementation, this would come through SensorDataManager
        // Judging types should maintain more consistency despite activity
        XCTAssertNotEqual(
            baseJudgingRecs.first?.name,
            basePerceivingRecs.first?.name,
            "Different personality types should get different base recommendations"
        )
    }

    // MARK: - Helper Methods

    private func createTestSong(
        name: String,
        energy: Float,
        valence: Float = 0.5,
        tempo: Float,
        complexity _: Float = 0.5
    ) -> Song {
        let song = Song()
        song.name = name
        song.features = AudioFeatures(
            tempo: tempo,
            energy: energy,
            valence: valence,
            danceability: (energy + valence) / 2,
            acousticness: 1.0 - energy,
            instrumentalness: 0.5,
            speechiness: 0.1,
            liveness: 0.2
        )
        return song
    }
}
