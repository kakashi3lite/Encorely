import Foundation

/// A comprehensive representation of audio characteristics.
///
/// `AudioFeatures` encapsulates various aspects of audio analysis including:
/// - Energy levels
/// - Emotional valence
/// - Dynamic intensity
/// - Timbral features
///
/// ## Overview
///
/// AudioFeatures provides a rich set of metrics for analyzing and categorizing audio,
/// particularly useful for mood detection and music recommendation.
///
/// ```swift
/// // Create features for analysis
/// let features = AudioFeatures(
///     energy: 0.8,
///     valence: 0.6,
///     intensity: 0.7,
///     complexity: 0.5,
///     brightness: 0.6,
///     warmth: 0.4
/// )
///
/// // Check mood indicators
/// if features.isEnergetic {
///     print("High energy track!")
/// }
/// ```
///
/// ## Topics
///
/// ### Creating Features
/// - ``init(energy:valence:intensity:complexity:brightness:warmth:)``
/// - ``neutral``
///
/// ### Core Metrics
/// - ``energy``
/// - ``valence``
/// - ``intensity``
///
/// ### Timbral Analysis
/// - ``complexity``
/// - ``brightness``
/// - ``warmth``
///
/// ### Analysis Helpers
/// - ``moodVector``
/// - ``distance(to:)``
///
/// ### State Indicators
/// - ``isEnergetic``
/// - ``isCalm``
/// - ``isPositive``
/// - ``isNegative``
/// - ``isIntense``
/// - ``isComplex``
/// - ``isBright``
/// - ``isWarm``
public struct AudioFeatures {
    // Core emotional features
    let energy: Float      // Overall energy/intensity of the audio (0-1)
    let valence: Float    // Musical positiveness/mood (0-1)
    let intensity: Float  // Dynamic intensity/arousal (0-1)
    
    // Timbral features
    let complexity: Float // Spectral complexity/richness (0-1)
    let brightness: Float // High frequency content (0-1)
    let warmth: Float    // Bass/treble ratio, indicates warmth (0-1)
    
    // Default initialization with neutral values
    static var neutral: AudioFeatures {
        AudioFeatures(
            energy: 0.5,
            valence: 0.5,
            intensity: 0.5,
            complexity: 0.5,
            brightness: 0.5,
            warmth: 0.5
        )
    }
    
    // Utilities for mood detection
    public var moodVector: [Float] {
        [energy, valence, intensity]
    }
    
    public func distance(to other: AudioFeatures) -> Float {
        let v1 = moodVector
        let v2 = other.moodVector
        
        var sum: Float = 0
        vDSP_distancesq(v1, 1, v2, 1, &sum, vDSP_Length(v1.count))
        
        var result: Float = 0
        vvsqrtf(&result, &sum, [1])
        
        return result
    }
    
    // Analysis helpers
    var isEnergetic: Bool { energy > 0.7 }
    var isCalm: Bool { energy < 0.3 }
    var isPositive: Bool { valence > 0.7 }
    var isNegative: Bool { valence < 0.3 }
    var isIntense: Bool { intensity > 0.7 }
    var isComplex: Bool { complexity > 0.7 }
    var isBright: Bool { brightness > 0.7 }
    var isWarm: Bool { warmth > 0.7 }
}

extension AudioFeatures: CustomStringConvertible {
    var description: String {
        """
        AudioFeatures:
         - Energy: \(String(format: "%.2f", energy))
         - Valence: \(String(format: "%.2f", valence))
         - Intensity: \(String(format: "%.2f", intensity))
         - Complexity: \(String(format: "%.2f", complexity))
         - Brightness: \(String(format: "%.2f", brightness))
         - Warmth: \(String(format: "%.2f", warmth))
        """
    }
}

extension AudioFeatures {
    /// Returns the Euclidean distance between two audio feature sets.
    ///
    /// Use this method to compare the similarity between two audio samples:
    /// ```swift
    /// let distance = features1.distance(to: features2)
    /// if distance < 0.5 {
    ///     print("Audio samples are similar!")
    /// }
    /// ```
    ///
    /// - Parameter other: The audio features to compare against
    /// - Returns: The Euclidean distance between the feature vectors
    public func distance(to other: AudioFeatures) -> Float {
        let v1 = moodVector
        let v2 = other.moodVector
        
        var sum: Float = 0
        vDSP_distancesq(v1, 1, v2, 1, &sum, vDSP_Length(v1.count))
        
        var result: Float = 0
        vvsqrtf(&result, &sum, [1])
        
        return result
    }
    
    /// A vector representation of the core mood features.
    ///
    /// This property combines energy, valence, and intensity into a
    /// three-dimensional vector suitable for mood classification.
    ///
    /// - Returns: An array containing [energy, valence, intensity]
    public var moodVector: [Float] {
        [energy, valence, intensity]
    }
}
