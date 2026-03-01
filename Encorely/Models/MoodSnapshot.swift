import Foundation
import SwiftData

/// A point-in-time record of mood detection, used for mood history charts.
@Model
final class MoodSnapshot {
    /// Unique identifier.
    @Attribute(.unique) var snapshotID: String

    /// Detected mood stored as raw string.
    var moodRaw: String

    /// Confidence in the detection (0.0–1.0).
    var confidence: Float

    /// When this snapshot was taken.
    var timestamp: Date

    /// Time-of-day context when recorded.
    var timeContextRaw: String

    /// JSON-encoded AudioFeatures that produced this mood.
    var audioFeaturesData: Data?

    init(mood: Mood, confidence: Float, audioFeatures: AudioFeatures? = nil) {
        self.snapshotID = UUID().uuidString
        self.moodRaw = mood.rawValue
        self.confidence = confidence
        self.timestamp = Date()
        self.timeContextRaw = TimeContext.current.rawString
        self.audioFeaturesData = try? JSONEncoder().encode(audioFeatures)
    }

    /// Decoded mood value.
    var mood: Mood {
        Mood(rawValue: moodRaw) ?? .happy
    }

    /// Decoded audio features.
    var audioFeatures: AudioFeatures? {
        guard let data = audioFeaturesData else { return nil }
        return try? JSONDecoder().decode(AudioFeatures.self, from: data)
    }
}

// MARK: - TimeContext persistence helper

extension TimeContext {
    /// String representation for SwiftData storage.
    var rawString: String {
        switch self {
        case .morning:   "morning"
        case .afternoon: "afternoon"
        case .evening:   "evening"
        case .night:     "night"
        }
    }

    init(rawString: String) {
        switch rawString {
        case "morning":   self = .morning
        case "afternoon": self = .afternoon
        case "evening":   self = .evening
        case "night":     self = .night
        default:          self = .morning
        }
    }
}
