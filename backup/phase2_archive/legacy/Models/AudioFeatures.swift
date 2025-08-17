import AVFoundation
import Foundation

/// Audio features extracted from analysis
struct AudioFeatures: Codable {
    var tempo: Float?
    var energy: Float?
    var valence: Float?
    var complexity: Float?
    var brightness: Float?
    var warmth: Float?

    init(tempo: Float? = nil,
         energy: Float? = nil,
         valence: Float? = nil,
         complexity: Float? = nil,
         brightness: Float? = nil,
         warmth: Float? = nil)
    {
        self.tempo = tempo
        self.energy = energy
        self.valence = valence
        self.complexity = complexity
        self.brightness = brightness
        self.warmth = warmth
    }

    /// Calculate distance between two feature sets
    func distance(to other: AudioFeatures) -> Float {
        var totalDistance: Float = 0
        var featureCount = 0

        if let t1 = tempo, let t2 = other.tempo {
            totalDistance += abs(t1 - t2) / 180.0 // Normalize to typical BPM range
            featureCount += 1
        }

        if let e1 = energy, let e2 = other.energy {
            totalDistance += abs(e1 - e2)
            featureCount += 1
        }

        if let v1 = valence, let v2 = other.valence {
            totalDistance += abs(v1 - v2)
            featureCount += 1
        }

        if let c1 = complexity, let c2 = other.complexity {
            totalDistance += abs(c1 - c2)
            featureCount += 1
        }

        if let b1 = brightness, let b2 = other.brightness {
            totalDistance += abs(b1 - b2)
            featureCount += 1
        }

        if let w1 = warmth, let w2 = other.warmth {
            totalDistance += abs(w1 - w2)
            featureCount += 1
        }

        return featureCount > 0 ? totalDistance / Float(featureCount) : 1.0
    }

    /// Calculate similarity score between two feature sets
    func similarity(to other: AudioFeatures) -> Float {
        1.0 - distance(to: other)
    }
}
