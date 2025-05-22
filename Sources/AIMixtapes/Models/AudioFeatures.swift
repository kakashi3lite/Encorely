import Foundation
import Accelerate

public struct AudioFeatures {
    // Core emotional features
    public let energy: Float      // Overall energy/intensity of the audio (0-1)
    public let valence: Float     // Musical positiveness/mood (0-1)
    public let intensity: Float   // Dynamic intensity/arousal (0-1)
    
    // Timbral features
    public let complexity: Float  // Spectral complexity/richness (0-1)
    public let brightness: Float  // High frequency content (0-1)
    public let warmth: Float     // Bass/treble ratio, indicates warmth (0-1)
    
    public init(
        energy: Float,
        valence: Float,
        intensity: Float,
        complexity: Float,
        brightness: Float,
        warmth: Float
    ) {
        self.energy = energy
        self.valence = valence
        self.intensity = intensity
        self.complexity = complexity
        self.brightness = brightness
        self.warmth = warmth
    }
    
    // Default initialization with neutral values
    public static var neutral: AudioFeatures {
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
    public var isEnergetic: Bool { energy > 0.7 }
    public var isCalm: Bool { energy < 0.3 }
    public var isPositive: Bool { valence > 0.7 }
    public var isNegative: Bool { valence < 0.3 }
    public var isIntense: Bool { intensity > 0.7 }
    public var isComplex: Bool { complexity > 0.7 }
    public var isBright: Bool { brightness > 0.7 }
    public var isWarm: Bool { warmth > 0.7 }
}

extension AudioFeatures: CustomStringConvertible {
    public var description: String {
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
