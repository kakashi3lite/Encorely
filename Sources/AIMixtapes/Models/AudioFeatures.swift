import Accelerate
import Foundation
import SharedTypes

/// Spectral features extracted from audio analysis
public struct SpectralFeatures: Codable, Equatable {
    // Core spectral features
    public var centroid: Float = 0 // Weighted mean frequency
    public var spread: Float = 0 // Variance around centroid
    public var rolloff: Float = 0 // Frequency below which 85% of energy lies
    public var flux: Float = 0 // Frame-to-frame spectral difference
    public var zeroCrossingRate: Float = 0 // Rate of sign changes in time domain
    public var flatness: Float = 0 // Ratio of geometric to arithmetic mean

    // Energy distribution
    public var bassEnergy: Float = 0 // Energy in 20-250 Hz
    public var midEnergy: Float = 0 // Energy in 250-4000 Hz
    public var trebleEnergy: Float = 0 // Energy above 4000 Hz

    // Perceptual features
    public var brightness: Float = 0 // High-frequency energy ratio
    public var roughness: Float = 0 // Sensory dissonance
    public var spectralContrast: Float = 0 // Valley/peak ratio
    public var harmonicRatio: Float = 0 // Harmonic vs noise energy

    // Additional metrics
    public var crest: Float = 0 // Peak to average ratio
    public var irregularity: Float = 0 // Successive peak variation
    public var skewness: Float = 0 // Spectral asymmetry
    public var kurtosis: Float = 0 // Spectral peakedness
    public var dynamicRange: Float = 0 // dB range
    public var beatStrength: Float = 0 // Temporal accentuation
    public var estimatedTempo: Float = 0 // BPM estimate

    /// An empty instance of spectral features
    public static var empty: SpectralFeatures {
        SpectralFeatures()
    }

    /// A moderate spectral profile for neutral sound
    public static var neutral: SpectralFeatures {
        var features = SpectralFeatures()
        features.bassEnergy = 0.33
        features.midEnergy = 0.33
        features.trebleEnergy = 0.33
        features.brightness = 0.5
        features.centroid = 2000
        features.harmonicRatio = 0.5
        features.estimatedTempo = 100
        features.beatStrength = 0.5
        return features
    }
}

/// Enhanced audio features with all Spotify-like characteristics
public struct AudioFeatures: Codable {
    // MARK: - Core Features

    /// Tempo in beats per minute
    public let tempo: Float

    /// Overall energy/intensity (0.0 to 1.0)
    public let energy: Float

    /// Musical positiveness/mood (0.0 to 1.0)
    public let valence: Float

    /// Suitability for dancing (0.0 to 1.0)
    public let danceability: Float

    /// Acoustic vs. electronic measure (0.0 to 1.0)
    public let acousticness: Float

    /// Instrumental vs. vocal content (0.0 to 1.0)
    public let instrumentalness: Float

    /// Presence of spoken words (0.0 to 1.0)
    public let speechiness: Float

    /// Live performance probability (0.0 to 1.0)
    public let liveness: Float

    /// Detailed spectral features
    var spectralFeatures: SpectralFeatures?

    // MARK: - Initialization

    public init(
        tempo: Float,
        energy: Float,
        valence: Float,
        danceability: Float,
        acousticness: Float,
        instrumentalness: Float,
        speechiness: Float,
        liveness: Float,
        spectralFeatures: SpectralFeatures? = nil
    ) {
        self.tempo = tempo
        self.energy = energy
        self.valence = valence
        self.danceability = danceability
        self.acousticness = acousticness
        self.instrumentalness = instrumentalness
        self.speechiness = speechiness
        self.liveness = liveness
        self.spectralFeatures = spectralFeatures
    }

    // MARK: - Convenience Properties

    /// Returns true if energy is high
    public var isEnergetic: Bool {
        energy > 0.7
    }

    /// Returns true if valence is positive
    public var isPositive: Bool {
        valence > 0.6
    }

    /// Returns true if music is likely peaceful
    public var isPeaceful: Bool {
        energy < 0.4 && acousticness > 0.7
    }

    /// Returns true if music is likely intense
    public var isIntense: Bool {
        energy > 0.8 && danceability < 0.5
    }

    /// Returns true if music is likely melancholic
    public var isMelancholic: Bool {
        valence < 0.4 && tempo < 100
    }

    /// Returns a 3-dimension vector (energy, valence, danceability) for mood mapping
    public var moodVector: SIMD3<Float> {
        SIMD3<Float>(energy, valence, danceability)
    }

    // MARK: - Analysis Methods

    /// Calculates the distance between this feature set and another
    public func distance(to other: AudioFeatures) -> Float {
        var sum: Float = 0.0
        let v1 = [tempo / 200.0, energy, valence, danceability, acousticness, instrumentalness, speechiness, liveness]
        let v2 = [
            other.tempo / 200.0,
            other.energy,
            other.valence,
            other.danceability,
            other.acousticness,
            other.instrumentalness,
            other.speechiness,
            other.liveness,
        ]

        vDSP_distancesq(v1, 1, v2, 1, &sum, vDSP_Length(v1.count))
        var result: Float = 0
        vvsqrtf(&result, &sum, [1])

        return result
    }

    // MARK: - Factory Methods

    /// Default audio features with neutral values
    public static let `default` = AudioFeatures(
        tempo: 120.0,
        energy: 0.5,
        valence: 0.5,
        danceability: 0.5,
        acousticness: 0.5,
        instrumentalness: 0.5,
        speechiness: 0.1,
        liveness: 0.1
    )

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case tempo, energy, valence, danceability, acousticness, instrumentalness, speechiness, liveness,
             spectralFeatures
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tempo = try container.decode(Float.self, forKey: .tempo)
        energy = try container.decode(Float.self, forKey: .energy)
        valence = try container.decode(Float.self, forKey: .valence)
        danceability = try container.decode(Float.self, forKey: .danceability)
        acousticness = try container.decode(Float.self, forKey: .acousticness)
        instrumentalness = try container.decode(Float.self, forKey: .instrumentalness)
        speechiness = try container.decode(Float.self, forKey: .speechiness)
        liveness = try container.decode(Float.self, forKey: .liveness)
        spectralFeatures = try container.decodeIfPresent(SpectralFeatures.self, forKey: .spectralFeatures)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tempo, forKey: .tempo)
        try container.encode(energy, forKey: .energy)
        try container.encode(valence, forKey: .valence)
        try container.encode(danceability, forKey: .danceability)
        try container.encode(acousticness, forKey: .acousticness)
        try container.encode(instrumentalness, forKey: .instrumentalness)
        try container.encode(speechiness, forKey: .speechiness)
        try container.encode(liveness, forKey: .liveness)
        try container.encodeIfPresent(spectralFeatures, forKey: .spectralFeatures)
    }
}
