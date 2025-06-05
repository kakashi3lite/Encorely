import Foundation

public struct AudioFeatures: Codable {
    // MARK: - Properties
    
    // Core Features
    public var rms: Float
    public var peakAmplitude: Float?
    public var zeroCrossingRate: Float
    public var crest: Float?
    
    // Temporal Features
    public var pitch: Float?
    public var pitchConfidence: Float?
    public var tempo: Float?
    public var rhythmStrength: Float?
    
    // Spectral Features
    public var spectralCentroid: Float
    public var spectralRolloff: Float
    public var spectralFlatness: Float?
    public var spectralSpread: Float?
    public var spectralSkewness: Float?
    public var spectralKurtosis: Float?
    public var spectralFlux: Float?
    public var harmonicRatio: Float?
    
    // Band Energy Features
    public var bassEnergy: Float?
    public var midEnergy: Float?
    public var trebleEnergy: Float?
    public var subBandEnergies: [Float]?
    
    // Perceptual Features
    public var brightness: Float?
    public var warmth: Float?
    public var roughness: Float?
    public var spectralEntropy: Float?
    
    // MFCC Features
    public var mfcc: [Float]
    
    // Derived Features
    public var energy: Float {
        return rms * rms
    }
    
    public var dynamicRange: Float? {
        guard let peak = peakAmplitude else { return nil }
        return 20 * log10(peak / (rms + Float.ulpOfOne))
    }
    
    // MARK: - Initialization
    
    public init(
        rms: Float = 0,
        peakAmplitude: Float? = nil,
        zeroCrossingRate: Float = 0,
        crest: Float? = nil,
        pitch: Float? = nil,
        pitchConfidence: Float? = nil,
        tempo: Float? = nil,
        rhythmStrength: Float? = nil,
        spectralCentroid: Float = 0,
        spectralRolloff: Float = 0,
        spectralFlatness: Float? = nil,
        spectralSpread: Float? = nil,
        spectralSkewness: Float? = nil,
        spectralKurtosis: Float? = nil,
        spectralFlux: Float? = nil,
        harmonicRatio: Float? = nil,
        bassEnergy: Float? = nil,
        midEnergy: Float? = nil,
        trebleEnergy: Float? = nil,
        subBandEnergies: [Float]? = nil,
        brightness: Float? = nil,
        warmth: Float? = nil,
        roughness: Float? = nil,
        spectralEntropy: Float? = nil,
        mfcc: [Float] = Array(repeating: 0, count: 13)
    ) {
        self.rms = rms
        self.peakAmplitude = peakAmplitude
        self.zeroCrossingRate = zeroCrossingRate
        self.crest = crest
        self.pitch = pitch
        self.pitchConfidence = pitchConfidence
        self.tempo = tempo
        self.rhythmStrength = rhythmStrength
        self.spectralCentroid = spectralCentroid
        self.spectralRolloff = spectralRolloff
        self.spectralFlatness = spectralFlatness
        self.spectralSpread = spectralSpread
        self.spectralSkewness = spectralSkewness
        self.spectralKurtosis = spectralKurtosis
        self.spectralFlux = spectralFlux
        self.harmonicRatio = harmonicRatio
        self.bassEnergy = bassEnergy
        self.midEnergy = midEnergy
        self.trebleEnergy = trebleEnergy
        self.subBandEnergies = subBandEnergies
        self.brightness = brightness
        self.warmth = warmth
        self.roughness = roughness
        self.spectralEntropy = spectralEntropy
        self.mfcc = mfcc
    }
    
    // MARK: - Utility Methods
    
    /// Computes similarity between two feature sets using weighted Euclidean distance
    public func similarity(to other: AudioFeatures) -> Float {
        var score: Float = 0
        var weightSum: Float = 0
        
        // Define feature weights
        let weights: [String: Float] = [
            "rms": 1.0,
            "zeroCrossingRate": 0.8,
            "spectralCentroid": 1.0,
            "spectralRolloff": 0.8,
            "bassEnergy": 1.2,
            "midEnergy": 1.0,
            "trebleEnergy": 0.8,
            "harmonicRatio": 1.0,
            "brightness": 0.9
        ]
        
        // Compare RMS (energy)
        score += compareFeature(rms, other.rms, weight: weights["rms"]!)
        weightSum += weights["rms"]!
        
        // Compare ZCR
        score += compareFeature(zeroCrossingRate, other.zeroCrossingRate, weight: weights["zeroCrossingRate"]!)
        weightSum += weights["zeroCrossingRate"]!
        
        // Compare spectral features
        score += compareFeature(spectralCentroid, other.spectralCentroid, weight: weights["spectralCentroid"]!)
        weightSum += weights["spectralCentroid"]!
        
        score += compareFeature(spectralRolloff, other.spectralRolloff, weight: weights["spectralRolloff"]!)
        weightSum += weights["spectralRolloff"]!
        
        // Compare band energies if available
        if let bass1 = bassEnergy, let bass2 = other.bassEnergy {
            score += compareFeature(bass1, bass2, weight: weights["bassEnergy"]!)
            weightSum += weights["bassEnergy"]!
        }
        
        if let mid1 = midEnergy, let mid2 = other.midEnergy {
            score += compareFeature(mid1, mid2, weight: weights["midEnergy"]!)
            weightSum += weights["midEnergy"]!
        }
        
        if let treble1 = trebleEnergy, let treble2 = other.trebleEnergy {
            score += compareFeature(treble1, treble2, weight: weights["trebleEnergy"]!)
            weightSum += weights["trebleEnergy"]!
        }
        
        // Compare MFCCs
        let mfccWeight: Float = 0.5
        let mfccSimilarity = compareMFCCs(mfcc, other.mfcc)
        score += mfccSimilarity * mfccWeight
        weightSum += mfccWeight
        
        return score / weightSum
    }
    
    /// Create interpolated features between two sets
    public static func interpolate(_ a: AudioFeatures, _ b: AudioFeatures, t: Float) -> AudioFeatures {
        var result = AudioFeatures()
        
        // Interpolate basic features
        result.rms = lerp(a.rms, b.rms, t: t)
        result.zeroCrossingRate = lerp(a.zeroCrossingRate, b.zeroCrossingRate, t: t)
        result.spectralCentroid = lerp(a.spectralCentroid, b.spectralCentroid, t: t)
        result.spectralRolloff = lerp(a.spectralRolloff, b.spectralRolloff, t: t)
        
        // Interpolate optional features
        result.spectralFlatness = interpolateOptional(a.spectralFlatness, b.spectralFlatness, t: t)
        result.spectralSpread = interpolateOptional(a.spectralSpread, b.spectralSpread, t: t)
        result.bassEnergy = interpolateOptional(a.bassEnergy, b.bassEnergy, t: t)
        result.midEnergy = interpolateOptional(a.midEnergy, b.midEnergy, t: t)
        result.trebleEnergy = interpolateOptional(a.trebleEnergy, b.trebleEnergy, t: t)
        
        // Interpolate MFCC coefficients
        result.mfcc = zip(a.mfcc, b.mfcc).map { lerp($0.0, $0.1, t: t) }
        
        return result
    }
    
    // MARK: - Private Helper Methods
    
    private func compareFeature(_ a: Float, _ b: Float, weight: Float) -> Float {
        let diff = abs(a - b)
        let max = Swift.max(abs(a), abs(b))
        let normalizedDiff = max > 0 ? diff / max : 0
        return (1 - normalizedDiff) * weight
    }
    
    private func compareMFCCs(_ a: [Float], _ b: [Float]) -> Float {
        let count = min(a.count, b.count)
        guard count > 0 else { return 0 }
        
        var similarity: Float = 0
        for i in 0..<count {
            similarity += compareFeature(a[i], b[i], weight: 1.0)
        }
        
        return similarity / Float(count)
    }
    
    private static func lerp(_ a: Float, _ b: Float, t: Float) -> Float {
        return a + (b - a) * t
    }
    
    private static func interpolateOptional(_ a: Float?, _ b: Float?, t: Float) -> Float? {
        guard let a = a, let b = b else { return nil }
        return lerp(a, b, t: t)
    }
}

// MARK: - Factory Methods

extension AudioFeatures {
    /// Creates a default instance for testing
    public static var empty: AudioFeatures {
        AudioFeatures()
    }
    
    /// Creates features optimized for speech content
    public static func speech(energy: Float, pitch: Float) -> AudioFeatures {
        var features = AudioFeatures()
        features.rms = energy
        features.pitch = pitch
        features.spectralRolloff = 2000 // Typical speech rolloff
        features.spectralCentroid = 1000 // Typical speech centroid
        return features
    }
    
    /// Creates features optimized for musical content
    public static func music(energy: Float, tempo: Float) -> AudioFeatures {
        var features = AudioFeatures()
        features.rms = energy
        features.tempo = tempo
        features.spectralRolloff = 8000 // Wider frequency range
        features.spectralCentroid = 3000 // Higher centroid for music
        return features
    }
    
    /// Creates features from spectral analysis results
    public static func from(spectralFeatures: SpectralFeatures) -> AudioFeatures {
        var features = AudioFeatures()
        features.spectralCentroid = spectralFeatures.centroid
        features.spectralRolloff = spectralFeatures.rolloff
        features.spectralFlatness = spectralFeatures.flatness
        features.spectralSpread = spectralFeatures.spread
        features.bassEnergy = spectralFeatures.bassEnergy
        features.midEnergy = spectralFeatures.midEnergy
        features.trebleEnergy = spectralFeatures.trebleEnergy
        features.harmonicRatio = spectralFeatures.harmonicRatio
        features.brightness = spectralFeatures.brightness
        features.spectralFlux = spectralFeatures.flux
        return features
    }
}
