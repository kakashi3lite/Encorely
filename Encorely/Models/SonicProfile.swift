import Foundation
import SwiftData
import SwiftUI

// MARK: - STOMP Genre Definitions

/// The 14 music genres from the Short Test of Music Preferences (STOMP).
/// Each genre maps to one of four psychological dimensions.
/// Source: Rentfrow & Gosling, UT Austin.
public enum STOMPGenre: String, Codable, CaseIterable, Identifiable, Sendable {
    case classical   = "Classical"
    case jazz        = "Jazz"
    case blues       = "Blues"
    case folk        = "Folk"
    case rock        = "Rock"
    case alternative = "Alternative"
    case heavyMetal  = "Heavy Metal"
    case punk        = "Punk"
    case pop         = "Pop"
    case country     = "Country"
    case religious   = "Religious"
    case soundtracks = "Soundtracks"
    case rapHipHop   = "Rap / Hip-Hop"
    case electronica = "Electronica"

    public var id: String { rawValue }

    /// The STOMP dimension this genre belongs to.
    public var dimension: STOMPDimension {
        switch self {
        case .classical, .jazz, .blues, .folk:
            return .reflectiveComplex
        case .rock, .alternative, .heavyMetal, .punk:
            return .intenseRebellious
        case .pop, .country, .religious, .soundtracks:
            return .upbeatConventional
        case .rapHipHop, .electronica:
            return .energeticRhythmic
        }
    }

    /// SF Symbol for genre bubble display.
    public var icon: String {
        switch self {
        case .classical:   "music.note"
        case .jazz:        "music.quarternote.3"
        case .blues:       "guitars.fill"
        case .folk:        "leaf.fill"
        case .rock:        "guitars"
        case .alternative: "waveform.path"
        case .heavyMetal:  "bolt.fill"
        case .punk:        "flame.fill"
        case .pop:         "star.fill"
        case .country:     "sun.max.fill"
        case .religious:   "sparkles"
        case .soundtracks: "film"
        case .rapHipHop:   "headphones"
        case .electronica: "waveform"
        }
    }

    /// Display color per dimension for the bubble UI.
    public var bubbleColor: Color {
        dimension.color
    }
}

// MARK: - STOMP Dimensions

/// The four psychological dimensions of the STOMP model.
public enum STOMPDimension: String, Codable, CaseIterable, Sendable {
    case reflectiveComplex   = "Reflective & Complex"
    case intenseRebellious   = "Intense & Rebellious"
    case upbeatConventional  = "Upbeat & Conventional"
    case energeticRhythmic   = "Energetic & Rhythmic"

    /// Brand color for each dimension.
    public var color: Color {
        switch self {
        case .reflectiveComplex:  .indigo
        case .intenseRebellious:  .red
        case .upbeatConventional: .orange
        case .energeticRhythmic:  .cyan
        }
    }

    /// Short label for charts and indicators.
    public var shortLabel: String {
        switch self {
        case .reflectiveComplex:  "Reflective"
        case .intenseRebellious:  "Intense"
        case .upbeatConventional: "Upbeat"
        case .energeticRhythmic:  "Rhythmic"
        }
    }

    /// Genres belonging to this dimension.
    public var genres: [STOMPGenre] {
        STOMPGenre.allCases.filter { $0.dimension == self }
    }
}

// MARK: - Persisted Sonic Profile

/// SwiftData model storing the user's finalized Sonic Identity.
/// Created once during onboarding, updated as listening habits evolve.
@Model
public final class SonicProfile {
    /// Score for Reflective & Complex dimension (0.0 – 1.0).
    public var reflectiveComplex: Double

    /// Score for Intense & Rebellious dimension (0.0 – 1.0).
    public var intenseRebellious: Double

    /// Score for Upbeat & Conventional dimension (0.0 – 1.0).
    public var upbeatConventional: Double

    /// Score for Energetic & Rhythmic dimension (0.0 – 1.0).
    public var energeticRhythmic: Double

    /// User's energy baseline from the Mood Tuner (0.0 – 1.0).
    public var energyBaseline: Double

    /// Hex color string chosen in the Synesthesia picker. Drives app theme.
    public var synesthesiaColorHex: String

    /// Timestamp of profile creation.
    public var createdAt: Date

    /// Timestamp of last update.
    public var updatedAt: Date

    public init(
        reflectiveComplex: Double = 0,
        intenseRebellious: Double = 0,
        upbeatConventional: Double = 0,
        energeticRhythmic: Double = 0,
        energyBaseline: Double = 0.5,
        synesthesiaColorHex: String = "#00FFFF"
    ) {
        self.reflectiveComplex = reflectiveComplex
        self.intenseRebellious = intenseRebellious
        self.upbeatConventional = upbeatConventional
        self.energeticRhythmic = energeticRhythmic
        self.energyBaseline = energyBaseline
        self.synesthesiaColorHex = synesthesiaColorHex
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// The user's dominant STOMP dimension.
    public var dominantDimension: STOMPDimension {
        let scores: [(STOMPDimension, Double)] = [
            (.reflectiveComplex, reflectiveComplex),
            (.intenseRebellious, intenseRebellious),
            (.upbeatConventional, upbeatConventional),
            (.energeticRhythmic, energeticRhythmic),
        ]
        return scores.max(by: { $0.1 < $1.1 })?.0 ?? .upbeatConventional
    }

    /// Resolved SwiftUI color from the hex string.
    public var synesthesiaColor: Color {
        Color(hex: synesthesiaColorHex)
    }
}
