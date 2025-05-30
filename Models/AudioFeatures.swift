import Foundation
import Accelerate

/// Spectral features extracted from audio analysis
struct SpectralFeatures: Codable, Equatable {
    // Band energy distribution
    var bassEnergy: Float = 0
    var midEnergy: Float = 0
    var trebleEnergy: Float = 0
    
    // Spectral shape descriptors
    var brightness: Float = 0
    var centroid: Float = 0
    var spread: Float = 0
    var rolloff: Float = 0
    var flux: Float = 0
    var flatness: Float = 0
    var irregularity: Float = 0
    var crest: Float = 0
    var skewness: Float = 0
    var kurtosis: Float = 0
    var roughness: Float = 0
    
    // Perceptual features
    var harmonicRatio: Float = 0
    var spectralContrast: Float = 0
    var zeroCrossingRate: Float = 0
    var dynamicRange: Float = 0
    
    // Rhythmic features
    var estimatedTempo: Float = 0
    var beatStrength: Float = 0
    
    /// An empty instance of spectral features
    static var empty: SpectralFeatures {
        SpectralFeatures()
    }
    
    /// A moderate spectral profile for neutral sound
    static var neutral: SpectralFeatures {
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
        let v1 = [tempo/200.0, energy, valence, danceability, acousticness, instrumentalness, speechiness, liveness]
        let v2 = [other.tempo/200.0, other.energy, other.valence, other.danceability, other.acousticness, other.instrumentalness, other.speechiness, other.liveness]
        
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
        case tempo, energy, valence, danceability, acousticness, instrumentalness, speechiness, liveness, spectralFeatures
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
