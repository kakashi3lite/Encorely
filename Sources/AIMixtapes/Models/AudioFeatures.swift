import Foundation
import Accelerate
import SwiftUI

public struct AudioFeatures: Codable {
    // Core emotional features
    public let energy: Float      // Overall energy/intensity (0-1)
    public let valence: Float     // Musical positiveness (0-1) 
    public let intensity: Float   // Dynamic intensity/arousal (0-1)
    
    // Musical features
    public let tempo: Float?      // BPM
    public let key: Int?         // Musical key (-1 to 11)
    public let mode: Float?      // Major (1) vs Minor (0)
    public let danceability: Float? // Dance-ability (0-1)
    
    // Timbral features
    public let complexity: Float  // Spectral complexity (0-1)
    public let brightness: Float  // High frequency content (0-1)
    public let warmth: Float      // Bass/treble ratio (0-1)
    
    public init(
        energy: Float,
        valence: Float,
        intensity: Float,
        tempo: Float? = nil,
        key: Int? = nil,
        mode: Float? = nil,
        danceability: Float? = nil,
        complexity: Float,
        brightness: Float,
        warmth: Float
    ) {
        self.energy = energy
        self.valence = valence 
        self.intensity = intensity
        self.tempo = tempo
        self.key = key
        self.mode = mode
        self.danceability = danceability
        self.complexity = complexity
        self.brightness = brightness
        self.warmth = warmth
    }
    
    // Default neutral features
    public static var neutral: AudioFeatures {
        AudioFeatures(
            energy: 0.5,
            valence: 0.5,
            intensity: 0.5,
            tempo: 120,
            mode: 0.5,
            danceability: 0.5,
            complexity: 0.5,
            brightness: 0.5,
            warmth: 0.5
        )
    }

    // Factory methods for different moods
    public static func forMood(_ mood: Asset.MoodColor) -> AudioFeatures {
        switch mood {
        case .energetic:
            return AudioFeatures(
                energy: 0.9,
                valence: 0.8,
                intensity: 0.9,
                tempo: 140,
                mode: 1,
                danceability: 0.9,
                complexity: 0.7,
                brightness: 0.8,
                warmth: 0.6
            )
        case .relaxed:
            return AudioFeatures(
                energy: 0.3,
                valence: 0.6,
                intensity: 0.2,
                tempo: 80,
                mode: 1,
                danceability: 0.3,
                complexity: 0.4,
                brightness: 0.4,
                warmth: 0.8
            )
        case .happy:
            return AudioFeatures(
                energy: 0.7,
                valence: 0.9,
                intensity: 0.6,
                tempo: 120,
                mode: 1,
                danceability: 0.8,
                complexity: 0.6,
                brightness: 0.7,
                warmth: 0.6
            )
        case .melancholic:
            return AudioFeatures(
                energy: 0.4,
                valence: 0.2,
                intensity: 0.3,
                tempo: 85,
                mode: 0,
                danceability: 0.3,
                complexity: 0.7,
                brightness: 0.3,
                warmth: 0.7
            )
        case .focused:
            return AudioFeatures(
                energy: 0.5,
                valence: 0.5,
                intensity: 0.4,
                tempo: 100,
                mode: 0.5,
                danceability: 0.4,
                complexity: 0.6,
                brightness: 0.6,
                warmth: 0.5
            )
        case .romantic:
            return AudioFeatures(
                energy: 0.4,
                valence: 0.7,
                intensity: 0.3,
                tempo: 90,
                mode: 1,
                danceability: 0.5,
                complexity: 0.5,
                brightness: 0.4,
                warmth: 0.8
            )
        case .angry:
            return AudioFeatures(
                energy: 0.9,
                valence: 0.2,
                intensity: 1.0,
                tempo: 150,
                mode: 0,
                danceability: 0.6,
                complexity: 0.8,
                brightness: 0.9,
                warmth: 0.3
            )
        default:
            return .neutral
        }
    }
    
    // MARK: - Mood Detection Utilities
    
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
    
    public func predictMood() -> (mood: Asset.MoodColor, confidence: Float) {
        // Optimized: Use max(by:) instead of allocating array and sorting
        // This avoids creating intermediate array and O(n log n) sort
        var bestMood = Asset.MoodColor.neutral
        var bestConfidence: Float = 0.0
        
        for mood in Asset.MoodColor.allCases {
            let targetFeatures = AudioFeatures.forMood(mood)
            let similarity = 1.0 - min(distance(to: targetFeatures) / 2.0, 1.0)
            
            if similarity > bestConfidence {
                bestConfidence = similarity
                bestMood = mood
            }
        }
        
        return (bestMood, bestConfidence)
    }
    
    // MARK: - Analysis Helpers
    
    public var isEnergetic: Bool { energy > 0.7 }
    public var isCalm: Bool { energy < 0.3 }
    public var isPositive: Bool { valence > 0.7 }
    public var isNegative: Bool { valence < 0.3 }
    public var isIntense: Bool { intensity > 0.7 }
    public var isComplex: Bool { complexity > 0.7 }
    public var isBright: Bool { brightness > 0.7 }
    public var isWarm: Bool { warmth > 0.7 }
    
    public var dominantFeature: String {
        let features = [
            ("Energy", energy),
            ("Valence", valence),
            ("Intensity", intensity),
            ("Complexity", complexity),
            ("Brightness", brightness),
            ("Warmth", warmth)
        ]
        
        return features.max(by: { $0.1 < $1.1 })?.0 ?? "Balanced"
    }
}

extension AudioFeatures: CustomStringConvertible {
    public var description: String {
        var desc = [
            "AudioFeatures:",
            " - Energy: \(String(format: "%.2f", energy))",
            " - Valence: \(String(format: "%.2f", valence))",
            " - Intensity: \(String(format: "%.2f", intensity))"
        ]
        
        if let tempo = tempo {
            desc.append(" - Tempo: \(String(format: "%.1f", tempo)) BPM")
        }
        
        if let key = key {
            desc.append(" - Key: \(key)")
        }
        
        if let mode = mode {
            desc.append(" - Mode: \(mode > 0.5 ? "Major" : "Minor")")
        }
        
        desc.append(contentsOf: [
            " - Complexity: \(String(format: "%.2f", complexity))",
            " - Brightness: \(String(format: "%.2f", brightness))",
            " - Warmth: \(String(format: "%.2f", warmth))"
        ])
        
        return desc.joined(separator: "\n")
    }
}
