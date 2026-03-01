import Foundation
import SwiftData

/// A single song within a mixtape. Stores metadata and audio analysis data.
@Model
final class Song {
    /// Unique stable identifier for deduplication.
    @Attribute(.unique) var songID: String

    /// Display name of the song.
    var name: String

    /// Artist name.
    var artist: String

    /// Album name (if known).
    var albumName: String?

    /// Apple Music catalog identifier for MusicKit lookups.
    var appleMusicID: String?

    /// Position within the parent mixtape (0-based).
    var position: Int

    /// JSON-encoded AudioFeatures blob.
    var audioFeaturesData: Data?

    /// Single mood tag derived from audio analysis.
    var moodTag: String?

    /// Number of times this song has been played.
    var playCount: Int

    /// Duration in seconds.
    var duration: TimeInterval

    /// Artwork URL string (from MusicKit).
    var artworkURLString: String?

    /// Inverse relationship to parent mixtape.
    var mixtape: Mixtape?

    init(
        name: String,
        artist: String = "",
        albumName: String? = nil,
        appleMusicID: String? = nil,
        position: Int = 0,
        duration: TimeInterval = 0
    ) {
        self.songID = appleMusicID ?? UUID().uuidString
        self.name = name
        self.artist = artist
        self.albumName = albumName
        self.appleMusicID = appleMusicID
        self.position = position
        self.audioFeaturesData = nil
        self.moodTag = nil
        self.playCount = 0
        self.duration = duration
        self.artworkURLString = nil
        self.mixtape = nil
    }

    /// Decodes the stored audio features blob.
    var audioFeatures: AudioFeatures? {
        get {
            guard let data = audioFeaturesData else { return nil }
            return try? JSONDecoder().decode(AudioFeatures.self, from: data)
        }
        set {
            audioFeaturesData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Increments the play counter.
    func trackPlay() {
        playCount += 1
    }
}
