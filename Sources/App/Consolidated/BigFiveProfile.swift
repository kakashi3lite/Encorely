// filepath: Sources/App/Consolidated/BigFiveProfile.swift
import Foundation

/// Big Five (OCEAN) personality profile
public struct BigFiveProfile: Codable, Equatable {
    public var openness: Double // 0.0 ... 1.0
    public var conscientiousness: Double
    public var extraversion: Double
    public var agreeableness: Double
    public var neuroticism: Double

    public init(
        openness: Double,
        conscientiousness: Double,
        extraversion: Double,
        agreeableness: Double,
        neuroticism: Double
    ) {
        self.openness = openness.clamped01
        self.conscientiousness = conscientiousness.clamped01
        self.extraversion = extraversion.clamped01
        self.agreeableness = agreeableness.clamped01
        self.neuroticism = neuroticism.clamped01
    }
}

public extension BigFiveProfile {
    /// Soft-map Big Five to current PersonalityType buckets for UI behavior without changing screens.
    var mappedPersonalityType: PersonalityType {
        // Heuristic mapping keeping UI types stable
        if openness > 0.7, extraversion > 0.5 { return .explorer }
        if conscientiousness > 0.7 { return .planner }
        if openness > 0.65, agreeableness > 0.55 { return .creative }
        if abs(openness - conscientiousness) < 0.15, abs(extraversion - agreeableness) < 0.15 { return .balanced }
        return .analyzer
    }

    /// Weights for audio recommendation (0..1 multipliers)
    var audioPreferenceWeights: AudioPreferenceWeights {
        // Example weights derived from traits
        let energyPref = 0.3 * extraversion + 0.15 * (1 - neuroticism) + 0.1
        let complexityPref = 0.35 * openness + 0.1 * (1 - conscientiousness)
        let tempoPref = 0.25 * extraversion + 0.2 * openness
        let acousticnessPref = 0.25 * agreeableness + 0.15 * conscientiousness
        return AudioPreferenceWeights(
            energy: energyPref.clamped01,
            complexity: complexityPref.clamped01,
            tempo: tempoPref.clamped01,
            acousticness: acousticnessPref.clamped01
        )
    }
}

public struct AudioPreferenceWeights: Codable, Equatable {
    public var energy: Double
    public var complexity: Double
    public var tempo: Double
    public var acousticness: Double
}

private extension Double {
    var clamped01: Double { min(1.0, max(0.0, self)) }
}
