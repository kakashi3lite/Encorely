import Foundation
import SwiftUI

/// All mood states the app can detect and use for mixtape generation.
public enum Mood: String, Codable, CaseIterable, Identifiable {
    case energetic = "Energetic"
    case relaxed = "Relaxed"
    case happy = "Happy"
    case melancholic = "Melancholic"
    case focused = "Focused"
    case angry = "Angry"

    public var id: String { rawValue }

    /// SF Symbol icon for each mood.
    public var systemIcon: String {
        switch self {
        case .energetic:   "bolt.fill"
        case .relaxed:     "leaf.fill"
        case .happy:       "sun.max.fill"
        case .melancholic: "cloud.rain.fill"
        case .focused:     "target"
        case .angry:       "flame.fill"
        }
    }

    /// Default SwiftUI color for each mood.
    public var color: Color {
        switch self {
        case .energetic:   .orange
        case .relaxed:     .blue
        case .happy:       .yellow
        case .melancholic: .purple
        case .focused:     .green
        case .angry:       .red
        }
    }

    /// Keywords associated with each mood for search and tagging.
    public var keywords: [String] {
        switch self {
        case .energetic:   ["energy", "power", "workout", "upbeat", "dance", "fast"]
        case .relaxed:     ["calm", "chill", "peaceful", "gentle", "slow", "ambient"]
        case .happy:       ["joy", "uplifting", "cheerful", "bright", "optimistic"]
        case .melancholic: ["sad", "nostalgic", "emotional", "reflective", "longing"]
        case .focused:     ["concentration", "study", "work", "instrumental"]
        case .angry:       ["intense", "heavy", "aggressive", "powerful"]
        }
    }
}

/// Music personality types that influence recommendations and UI.
public enum PersonalityType: String, Codable, CaseIterable, Identifiable {
    case explorer = "Explorer"
    case curator = "Curator"
    case enthusiast = "Enthusiast"
    case analyzer = "Analyzer"
    case balanced = "Balanced"

    public var id: String { rawValue }

    /// Human-readable description of this personality type.
    public var typeDescription: String {
        switch self {
        case .explorer:   "Values discovery and variety in music"
        case .curator:    "Values organization and quality content"
        case .enthusiast: "Values deep dives and expertise"
        case .analyzer:   "Values technical details and precise control"
        case .balanced:   "Values balanced and adaptable experiences"
        }
    }

    /// Theme color for personality-driven UI tinting.
    public var themeColor: Color {
        switch self {
        case .explorer:   .purple
        case .curator:    .orange
        case .enthusiast: .green
        case .analyzer:   .blue
        case .balanced:   .gray
        }
    }
}

/// Audio features extracted from a song for mood detection and recommendations.
/// All values are normalized 0.0–1.0 except tempo (BPM).
public struct AudioFeatures: Codable, Sendable, Equatable {
    public var tempo: Float
    public var energy: Float
    public var valence: Float
    public var danceability: Float
    public var acousticness: Float
    public var instrumentalness: Float
    public var speechiness: Float
    public var liveness: Float

    public init(
        tempo: Float = 120,
        energy: Float = 0.5,
        valence: Float = 0.5,
        danceability: Float = 0.5,
        acousticness: Float = 0.5,
        instrumentalness: Float = 0.5,
        speechiness: Float = 0.1,
        liveness: Float = 0.1
    ) {
        self.tempo = tempo
        self.energy = energy
        self.valence = valence
        self.danceability = danceability
        self.acousticness = acousticness
        self.instrumentalness = instrumentalness
        self.speechiness = speechiness
        self.liveness = liveness
    }
}

/// Time-of-day context used for mood recommendations.
public enum TimeContext: Sendable {
    case morning, afternoon, evening, night

    /// Derives context from the current hour.
    public static var current: TimeContext {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default:      return .night
        }
    }
}
