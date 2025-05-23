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

/// Model for audio features with all Spotify-like characteristics
public struct AudioFeatures: Codable {
    public let tempo: Float              // Beats per minute
    public let energy: Float            // 0.0 to 1.0, intensity and activity level
    public let valence: Float           // 0.0 to 1.0, musical positiveness
    public let danceability: Float      // 0.0 to 1.0, suitability for dancing
    public let acousticness: Float      // 0.0 to 1.0, acoustic vs electronic
    public let instrumentalness: Float  // 0.0 to 1.0, vocal content prediction
    public let speechiness: Float       // 0.0 to 1.0, spoken word presence
    public let liveness: Float          // 0.0 to 1.0, audience presence
    
    // Computed property for overall energy score
    public var overallEnergy: Float {
        return (energy + danceability + (tempo / 180.0)) / 3.0
    }
    
    // Computed property for mood score
    public var moodScore: Float {
        return (valence + energy) / 2.0
    }
    
    // Computed property for focus score
    public var focusScore: Float {
        return instrumentalness * (1.0 - speechiness)
    }
    
    // Initialize with complete set of features
    public init(tempo: Float, energy: Float, valence: Float, danceability: Float = 0.5,
         acousticness: Float = 0.5, instrumentalness: Float = 0.5,
         speechiness: Float = 0.5, liveness: Float = 0.5) {
        self.tempo = tempo
        self.energy = energy
        self.valence = valence
        self.danceability = danceability
        self.acousticness = acousticness
        self.instrumentalness = instrumentalness
        self.speechiness = speechiness
        self.liveness = liveness
    }
    
    // Simplified constructor for basic analysis
    public init(tempo: Float, energy: Float, valence: Float) {
        self.init(tempo: tempo, energy: energy, valence: valence)
    }
    
    /// Enhanced audio features with additional metrics for improved mood detection
    struct AudioFeatures: Codable, Equatable {
        // MARK: - Core Feature Properties
        
        /// Energy level (0.0 - 1.0)
        var energy: Float?
        
        /// Emotional valence (0.0 = negative, 1.0 = positive)
        var valence: Float?
        
        /// Tempo in BPM
        var tempo: Float?
        
        /// Musical key (0 = C, 1 = C#, etc.)
        var key: Int?
        
        /// Mode (0 = minor, 1 = major)
        var mode: Float?
        
        /// Danceability measure (0.0 - 1.0)
        var danceability: Float?
        
        /// Acoustic vs. electric measure (0.0 - 1.0, higher = more acoustic)
        var acousticness: Float?
        
        /// Instrumental vs. vocal content (0.0 - 1.0, higher = more instrumental)
        var instrumentalness: Float?
        
        /// Presence of spoken words (0.0 - 1.0, higher = more speech-like)
        var speechiness: Float?
        
        /// Live performance probability (0.0 - 1.0)
        var liveness: Float?
        
        /// Detailed timbral and spectral features
        var spectralFeatures: SpectralFeatures?
        
        /// Time-domain features (attack time, decay, etc.)
        var temporalFeatures: [String: Float]?
        
        /// Rhythm features (beat strength, rhythmic complexity)
        var rhythmFeatures: [String: Float]?
        
        // MARK: - Initialization
        
        /// Initialize with the most common features
        init(tempo: Float? = nil, 
             energy: Float? = nil, 
             valence: Float? = nil, 
             danceability: Float? = nil,
             acousticness: Float? = nil,
             instrumentalness: Float? = nil,
             speechiness: Float? = nil,
             liveness: Float? = nil) {
            
            self.tempo = tempo
            self.energy = energy
            self.valence = valence
            self.danceability = danceability
            self.acousticness = acousticness
            self.instrumentalness = instrumentalness
            self.speechiness = speechiness
            self.liveness = liveness
        }
        
        /// Initialize with complete set of features
        init(tempo: Float? = nil,
             energy: Float? = nil,
             valence: Float? = nil,
             key: Int? = nil,
             mode: Float? = nil,
             danceability: Float? = nil,
             acousticness: Float? = nil,
             instrumentalness: Float? = nil,
             speechiness: Float? = nil,
             liveness: Float? = nil,
             spectralFeatures: SpectralFeatures? = nil,
             temporalFeatures: [String: Float]? = nil,
             rhythmFeatures: [String: Float]? = nil) {
            
            self.tempo = tempo
            self.energy = energy
            self.valence = valence
            self.key = key
            self.mode = mode
            self.danceability = danceability
            self.acousticness = acousticness
            self.instrumentalness = instrumentalness
            self.speechiness = speechiness
            self.liveness = liveness
            self.spectralFeatures = spectralFeatures
            self.temporalFeatures = temporalFeatures
            self.rhythmFeatures = rhythmFeatures
        }
        
        // MARK: - Analysis Helper Properties
        
        /// Returns true if energy is high
        var isEnergetic: Bool {
            guard let energy = energy else { return false }
            return energy > 0.7
        }
        
        /// Returns true if valence is positive
        var isPositive: Bool {
            guard let valence = valence else { return false }
            return valence > 0.6
        }
        
        /// Returns true if music is likely peaceful
        var isPeaceful: Bool {
            guard let energy = energy, let acousticness = acousticness else { return false }
            return energy < 0.4 && acousticness > 0.7
        }
        
        /// Returns true if music is likely intense
        var isIntense: Bool {
            guard let energy = energy, 
                  let danceability = danceability,
                  let spectralFeatures = spectralFeatures,
                  let roughness = spectralFeatures.roughness else { 
                return false 
            }
            return energy > 0.8 && danceability < 0.5 && roughness > 0.6
        }
        
        /// Returns true if music is likely melancholic
        var isMelancholic: Bool {
            guard let valence = valence, let mode = mode else { return false }
            return valence < 0.4 && mode < 0.5
        }
        
        /// Returns a 3-dimension vector (energy, valence, acoustic) for mood mapping
        var moodVector: SIMD3<Float> {
            SIMD3<Float>(
                energy ?? 0.5,
                valence ?? 0.5,
                acousticness ?? 0.5
            )
        }
        
        /// Duration string representation
        var durationString: String {
            guard let tempo = tempo else { return "Unknown" }
            
            // For a 4/4 time signature, we can estimate duration in minutes
            // based on tempo and a standard length of 32 bars
            let beatsPerBar = 4
            let numberOfBars = 32
            let totalBeats = Float(beatsPerBar * numberOfBars)
            
            let durationMinutes = totalBeats / tempo
            let minutes = Int(durationMinutes)
            let seconds = Int((durationMinutes - Float(minutes)) * 60)
            
            return String(format: "%d:%02d", minutes, seconds)
        }
        
        // MARK: - Factory Methods
        
        /// Creates a neutral set of audio features
        static var neutral: AudioFeatures {
            AudioFeatures(
                tempo: 120,
                energy: 0.5,
                valence: 0.5,
                key: 0,
                mode: 0.5,
                danceability: 0.5,
                acousticness: 0.5,
                instrumentalness: 0.5,
                speechiness: 0.1,
                liveness: 0.1,
                spectralFeatures: SpectralFeatures.neutral
            )
        }
        
        /// Creates a custom feature set optimized for specific mood
        static func forMood(_ mood: Mood) -> AudioFeatures {
            switch mood {
            case .energetic:
                return AudioFeatures(
                    tempo: 140,
                    energy: 0.9,
                    valence: 0.7,
                    danceability: 0.8,
                    acousticness: 0.2
                )
            case .relaxed:
                return AudioFeatures(
                    tempo: 75,
                    energy: 0.3,
                    valence: 0.6,
                    danceability: 0.3,
                    acousticness: 0.8
                )
            case .happy:
                return AudioFeatures(
                    tempo: 120,
                    energy: 0.7,
                    valence: 0.9,
                    danceability: 0.7,
                    acousticness: 0.5
                )
            case .melancholic:
                return AudioFeatures(
                    tempo: 85,
                    energy: 0.4,
                    valence: 0.3,
                    danceability: 0.3,
                    acousticness: 0.6
                )
            case .focused:
                return AudioFeatures(
                    tempo: 100,
                    energy: 0.5,
                    valence: 0.5,
                    danceability: 0.3,
                    acousticness: 0.4
                )
            case .romantic:
                return AudioFeatures(
                    tempo: 90,
                    energy: 0.4,
                    valence: 0.7,
                    danceability: 0.4,
                    acousticness: 0.7
                )
            case .angry:
                return AudioFeatures(
                    tempo: 135,
                    energy: 0.9,
                    valence: 0.2,
                    danceability: 0.5,
                    acousticness: 0.1
                )
            case .neutral:
                return neutral
            }
        }
        
        // MARK: - Analysis Methods
        
        /// Calculates the distance between this feature set and another
        /// - Parameter other: Another AudioFeatures instance to compare with
        /// - Returns: A normalized distance value between 0.0 (identical) and 1.0 (maximally different)
        func distance(to other: AudioFeatures) -> Float {
            let thisVector = moodVector
            let otherVector = other.moodVector
            
            // Use euclidean distance in 3D space
            let diff = thisVector - otherVector
            let distance = sqrt(dot(diff, diff))
            
            // Normalize to 0.0-1.0 range (sqrt(3) is max possible distance)
            return min(distance / sqrt(3.0), 1.0)
        }
        
        /// Returns a similarity score (0.0-1.0) with another feature set
        func similarity(to other: AudioFeatures) -> Float {
            return 1.0 - distance(to: other)
        }
    }
