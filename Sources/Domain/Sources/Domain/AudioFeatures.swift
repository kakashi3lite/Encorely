//
//  AudioFeatures.swift
//  Domain
//
//  Created by AI Assistant on 05/21/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation

/// Comprehensive audio feature analysis for mood detection and playlist generation
public struct AudioFeatures: Codable, Equatable {
    // Core audio characteristics
    public let tempo: Float           // Beats per minute (60-200 typical range)
    public let energy: Float          // 0.0-1.0, measures intensity and power
    public let valence: Float         // 0.0-1.0, musical positivity/happiness
    public let danceability: Float    // 0.0-1.0, rhythmic and groove elements
    
    // Advanced audio characteristics
    public let acousticness: Float    // 0.0-1.0, acoustic vs electronic
    public let instrumentalness: Float // 0.0-1.0, vocal content detection
    public let speechiness: Float     // 0.0-1.0, spoken word detection
    public let liveness: Float        // 0.0-1.0, live recording detection
    
    // Spectral characteristics
    public let spectralCentroid: Float? // Brightness/timbre indicator
    public let spectralRolloff: Float?  // High-frequency content
    public let zeroCrossingRate: Float? // Roughness/noisiness
    
    // Loudness characteristics
    public let loudness: Float?       // Overall loudness in dB
    public let dynamicRange: Float?   // Difference between loud and quiet parts
    
    public init(
        tempo: Float,
        energy: Float,
        valence: Float,
        danceability: Float = 0.5,
        acousticness: Float = 0.5,
        instrumentalness: Float = 0.5,
        speechiness: Float = 0.1,
        liveness: Float = 0.1,
        spectralCentroid: Float? = nil,
        spectralRolloff: Float? = nil,
        zeroCrossingRate: Float? = nil,
        loudness: Float? = nil,
        dynamicRange: Float? = nil
    ) {
        self.tempo = tempo
        self.energy = energy
        self.valence = valence
        self.danceability = danceability
        self.acousticness = acousticness
        self.instrumentalness = instrumentalness
        self.speechiness = speechiness
        self.liveness = liveness
        self.spectralCentroid = spectralCentroid
        self.spectralRolloff = spectralRolloff
        self.zeroCrossingRate = zeroCrossingRate
        self.loudness = loudness
        self.dynamicRange = dynamicRange
    }
}

// MARK: - AudioFeatures Extensions
public extension AudioFeatures {
    /// Overall energy combining multiple factors
    var overallEnergy: Float {
        return (energy + danceability + min(tempo / 180.0, 1.0)) / 3.0
    }
    
    /// Combined mood score from valence and energy
    var moodScore: Float {
        return (valence + energy) / 2.0
    }
    
    /// Focus-friendliness score (instrumental, non-speech)
    var focusScore: Float {
        return instrumentalness * (1.0 - speechiness)
    }
    
    /// Estimated mood category based on audio features
    var estimatedMood: EstimatedMood {
        switch (energy, valence) {
        case (0.7..., 0.6...): return .energetic
        case (0.0..<0.4, _): return .relaxed
        case (_, 0.7...): return .happy
        case (_, 0.0..<0.3): return .melancholic
        case (0.4..<0.7, 0.4..<0.6): return .focused
        default: return .neutral
        }
    }
    
    /// Default neutral features
    public static var neutral: AudioFeatures {
        AudioFeatures(
            tempo: 120.0,
            energy: 0.5,
            valence: 0.5,
            danceability: 0.5,
            acousticness: 0.5,
            instrumentalness: 0.5,
            speechiness: 0.1,
            liveness: 0.1
        )
    }
    
    /// Create mood-specific audio features
    public static func forMood(_ mood: MoodColor) -> AudioFeatures {
        switch mood {
        case .energetic:
            return AudioFeatures(
                tempo: 140.0,
                energy: 0.9,
                valence: 0.8,
                danceability: 0.9
            )
        case .relaxed:
            return AudioFeatures(
                tempo: 80.0,
                energy: 0.3,
                valence: 0.6,
                danceability: 0.3,
                acousticness: 0.8
            )
        case .happy:
            return AudioFeatures(
                tempo: 120.0,
                energy: 0.7,
                valence: 0.9,
                danceability: 0.8
            )
        case .melancholic:
            return AudioFeatures(
                tempo: 85.0,
                energy: 0.4,
                valence: 0.2,
                danceability: 0.3,
                acousticness: 0.7
            )
        case .focused:
            return AudioFeatures(
                tempo: 100.0,
                energy: 0.5,
                valence: 0.5,
                danceability: 0.4,
                instrumentalness: 0.8
            )
        case .romantic:
            return AudioFeatures(
                tempo: 90.0,
                energy: 0.4,
                valence: 0.7,
                danceability: 0.5,
                acousticness: 0.6
            )
        case .angry:
            return AudioFeatures(
                tempo: 150.0,
                energy: 0.9,
                valence: 0.2,
                danceability: 0.6
            )
        }
    }
}
