import Foundation

public struct AudioFeatures: Codable {
    // Energy and Amplitude Features
    public let rms: Float
    public let peakAmplitude: Float?
    
    // Temporal Features
    public let zeroCrossingRate: Float
    
    // Pitch Features
    public let pitch: Float?
    public let pitchConfidence: Float?
    
    // Spectral Features
    public let spectralCentroid: Float
    public let spectralRolloff: Float
    public let spectralFlatness: Float?
    public let spectralSpread: Float?
    
    // Band Energy Features
    public let bassEnergy: Float?
    public let midEnergy: Float?
    public let trebleEnergy: Float?
    
    // MFCC Features
    public let mfcc: [Float]
    
    // Derived Features (Optional)
    public var spectralEntropy: Float? {
        guard let flatness = spectralFlatness else { return nil }
        return -flatness * log2(flatness)
    }
    
    public var brightness: Float? {
        guard let spread = spectralSpread else { return nil }
        return spectralCentroid + spread
    }
    
    public init(
        rms: Float,
        peakAmplitude: Float? = nil,
        zeroCrossingRate: Float,
        pitch: Float? = nil,
        pitchConfidence: Float? = nil,
        spectralCentroid: Float,
        spectralRolloff: Float,
        spectralFlatness: Float? = nil,
        spectralSpread: Float? = nil,
        bassEnergy: Float? = nil,
        midEnergy: Float? = nil,
        trebleEnergy: Float? = nil,
        mfcc: [Float]
    ) {
        self.rms = rms
        self.peakAmplitude = peakAmplitude
        self.zeroCrossingRate = zeroCrossingRate
        self.pitch = pitch
        self.pitchConfidence = pitchConfidence
        self.spectralCentroid = spectralCentroid
        self.spectralRolloff = spectralRolloff
        self.spectralFlatness = spectralFlatness
        self.spectralSpread = spectralSpread
        self.bassEnergy = bassEnergy
        self.midEnergy = midEnergy
        self.trebleEnergy = trebleEnergy
        self.mfcc = mfcc
    }
    
    // Static Helpers
    
    /// Creates an instance with default values for testing
    public static var empty: AudioFeatures {
        AudioFeatures(
            rms: 0,
            peakAmplitude: 0,
            zeroCrossingRate: 0,
            pitch: 0,
            pitchConfidence: 0,
            spectralCentroid: 0,
            spectralRolloff: 0,
            spectralFlatness: 0,
            spectralSpread: 0,
            bassEnergy: 0,
            midEnergy: 0,
            trebleEnergy: 0,
            mfcc: Array(repeating: 0, count: 13)
        )
    }
    
    // Utility Methods
    
    /// Returns a similarity score (0-1) between two feature sets
    public func similarity(to other: AudioFeatures) -> Float {
        var score: Float = 0
        var count: Float = 0
        
        // Compare basic features
        score += 1 - abs(rms - other.rms)
        score += 1 - abs(zeroCrossingRate - other.zeroCrossingRate)
        score += 1 - abs(spectralCentroid - other.spectralCentroid) / spectralCentroid
        score += 1 - abs(spectralRolloff - other.spectralRolloff) / spectralRolloff
        count += 4
        
        // Compare optional features if available
        if let pitch1 = pitch, let pitch2 = other.pitch {
            score += 1 - abs(pitch1 - pitch2) / pitch1
            count += 1
        }
        
        if let flatness1 = spectralFlatness, let flatness2 = other.spectralFlatness {
            score += 1 - abs(flatness1 - flatness2)
            count += 1
        }
        
        if let spread1 = spectralSpread, let spread2 = other.spectralSpread {
            score += 1 - abs(spread1 - spread2) / spread1
            count += 1
        }
        
        // Compare band energies if available
        if let bass1 = bassEnergy, let bass2 = other.bassEnergy,
           let mid1 = midEnergy, let mid2 = other.midEnergy,
           let treble1 = trebleEnergy, let treble2 = other.trebleEnergy {
            score += 1 - abs(bass1 - bass2)
            score += 1 - abs(mid1 - mid2)
            score += 1 - abs(treble1 - treble2)
            count += 3
        }
        
        // Compare MFCCs
        let mfccScore = zip(mfcc, other.mfcc)
            .map { 1 - abs($0 - $1) }
            .reduce(0, +)
        score += mfccScore
        count += Float(mfcc.count)
        
        return score / count
    }
    
    /// Returns whether this feature set likely represents silence
    public var isSilence: Bool {
        rms < 0.01 && zeroCrossingRate < 0.01
    }
    
    /// Returns whether this feature set likely represents noise
    public var isNoise: Bool {
        spectralFlatness ?? 0 > 0.5 && zeroCrossingRate > 0.4
    }
}
