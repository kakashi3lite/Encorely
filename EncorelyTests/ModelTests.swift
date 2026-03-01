import Foundation
import Testing
@testable import Encorely

/// Tests for SwiftData model behavior (computed properties, methods).
struct ModelTests {
    // MARK: - Song Tests

    @Test("Song initializes with correct defaults")
    func songDefaults() {
        let song = Song(name: "Test Song", artist: "Test Artist")
        #expect(song.name == "Test Song")
        #expect(song.artist == "Test Artist")
        #expect(song.position == 0)
        #expect(song.playCount == 0)
        #expect(song.audioFeatures == nil)
    }

    @Test("Song trackPlay increments count")
    func songTrackPlay() {
        let song = Song(name: "Track")
        song.trackPlay()
        song.trackPlay()
        #expect(song.playCount == 2)
    }

    @Test("Song audio features roundtrip through JSON")
    func songAudioFeaturesRoundtrip() {
        let song = Song(name: "Analyzed")
        let features = AudioFeatures(tempo: 140, energy: 0.8, valence: 0.6)
        song.audioFeatures = features

        let decoded = song.audioFeatures
        #expect(decoded != nil)
        #expect(decoded?.tempo == 140)
        #expect(decoded?.energy == 0.8)
        #expect(decoded?.valence == 0.6)
    }

    @Test("Song with appleMusicID uses it as songID")
    func songWithAppleMusicID() {
        let song = Song(name: "AM Song", appleMusicID: "AM123")
        #expect(song.songID == "AM123")
    }

    // MARK: - Mixtape Tests

    @Test("Mixtape initializes with correct defaults")
    func mixtapeDefaults() {
        let mixtape = Mixtape(title: "My Mix")
        #expect(mixtape.title == "My Mix")
        #expect(mixtape.isAIGenerated == false)
        #expect(mixtape.playCount == 0)
        #expect(mixtape.songs.isEmpty)
        #expect(mixtape.songCount == 0)
    }

    @Test("Mixtape mood tag management")
    func mixtapeMoodTags() {
        let mixtape = Mixtape(title: "Tagged Mix")

        mixtape.addMoodTag("Happy")
        #expect(mixtape.moodTagsArray == ["Happy"])

        mixtape.addMoodTag("Energetic")
        #expect(mixtape.moodTagsArray.contains("Happy"))
        #expect(mixtape.moodTagsArray.contains("Energetic"))

        // Adding duplicate is ignored
        mixtape.addMoodTag("Happy")
        #expect(mixtape.moodTagsArray.filter { $0 == "Happy" }.count == 1)

        mixtape.removeMoodTag("Happy")
        #expect(!mixtape.moodTagsArray.contains("Happy"))
        #expect(mixtape.moodTagsArray.contains("Energetic"))
    }

    @Test("Mixtape trackPlay updates count and date")
    func mixtapeTrackPlay() {
        let mixtape = Mixtape(title: "Play Test")
        #expect(mixtape.lastPlayedDate == nil)

        mixtape.trackPlay()
        #expect(mixtape.playCount == 1)
        #expect(mixtape.lastPlayedDate != nil)
    }

    @Test("Mixtape totalDuration sums songs")
    func mixtapeTotalDuration() {
        let mixtape = Mixtape(title: "Duration Test")
        mixtape.songs.append(Song(name: "A", duration: 180))
        mixtape.songs.append(Song(name: "B", duration: 240))
        #expect(mixtape.totalDuration == 420)
    }

    // MARK: - UserProfile Tests

    @Test("UserProfile defaults to balanced")
    func userProfileDefaults() {
        let profile = UserProfile()
        #expect(profile.personalityType == .balanced)
        #expect(profile.confidence == 0.0)
        #expect(profile.profileID == "default")
    }

    @Test("UserProfile updateTraits changes personality")
    func userProfileUpdateTraits() {
        let profile = UserProfile()
        profile.updateTraits(
            openness: 0.9, conscientiousness: 0.3,
            extraversion: 0.4, agreeableness: 0.3,
            neuroticism: 0.2, confidence: 0.85
        )
        #expect(profile.personalityType == .explorer)
        #expect(profile.confidence == 0.85)
        #expect(profile.lastAnalysisDate != nil)
    }

    // MARK: - MoodSnapshot Tests

    @Test("MoodSnapshot stores mood and confidence")
    func snapshotStoresMood() {
        let snapshot = MoodSnapshot(mood: .focused, confidence: 0.75)
        #expect(snapshot.mood == .focused)
        #expect(snapshot.confidence == 0.75)
    }

    @Test("MoodSnapshot stores audio features")
    func snapshotStoresFeatures() {
        let features = AudioFeatures(tempo: 100, energy: 0.5)
        let snapshot = MoodSnapshot(mood: .relaxed, confidence: 0.8, audioFeatures: features)
        let decoded = snapshot.audioFeatures
        #expect(decoded?.tempo == 100)
        #expect(decoded?.energy == 0.5)
    }

    // MARK: - SharedTypes Tests

    @Test("All moods have system icons")
    func moodsHaveIcons() {
        for mood in Mood.allCases {
            #expect(!mood.systemIcon.isEmpty)
        }
    }

    @Test("All moods have keywords")
    func moodsHaveKeywords() {
        for mood in Mood.allCases {
            #expect(!mood.keywords.isEmpty)
        }
    }

    @Test("All personality types have descriptions")
    func personalitiesHaveDescriptions() {
        for type in PersonalityType.allCases {
            #expect(!type.typeDescription.isEmpty)
        }
    }

    @Test("AudioFeatures codable roundtrip")
    func audioFeaturesCodable() throws {
        let original = AudioFeatures(
            tempo: 128, energy: 0.7, valence: 0.6,
            danceability: 0.8, acousticness: 0.2,
            instrumentalness: 0.4, speechiness: 0.1, liveness: 0.15
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AudioFeatures.self, from: data)
        #expect(original == decoded)
    }

    @Test("TimeContext.current returns a valid value")
    func timeContextCurrent() {
        let context = TimeContext.current
        let rawString = context.rawString
        let restored = TimeContext(rawString: rawString)
        #expect(rawString == restored.rawString)
    }
}
