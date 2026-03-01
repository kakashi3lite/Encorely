import Foundation
import SwiftData

/// Stores the user's music personality profile and preferences.
/// Only one instance exists per device (singleton pattern in SwiftData).
@Model
final class UserProfile {
    /// Stable identifier (always "default" for the single profile).
    @Attribute(.unique) var profileID: String

    /// Detected personality type stored as raw string.
    var personalityRaw: String

    /// OCEAN personality trait scores (0.0–1.0).
    var openness: Double
    var conscientiousness: Double
    var extraversion: Double
    var agreeableness: Double
    var neuroticism: Double

    /// Confidence in the personality assessment (0.0–1.0).
    var confidence: Double

    /// Date of the last personality analysis.
    var lastAnalysisDate: Date?

    /// Total songs played (for engagement tracking).
    var totalPlays: Int

    /// Date the profile was created.
    var createdDate: Date

    init() {
        self.profileID = "default"
        self.personalityRaw = PersonalityType.balanced.rawValue
        self.openness = 0.5
        self.conscientiousness = 0.5
        self.extraversion = 0.5
        self.agreeableness = 0.5
        self.neuroticism = 0.5
        self.confidence = 0.0
        self.lastAnalysisDate = nil
        self.totalPlays = 0
        self.createdDate = Date()
    }

    /// Decoded personality type.
    var personalityType: PersonalityType {
        get { PersonalityType(rawValue: personalityRaw) ?? .balanced }
        set { personalityRaw = newValue.rawValue }
    }

    /// Updates OCEAN scores and recalculates personality type.
    func updateTraits(
        openness: Double,
        conscientiousness: Double,
        extraversion: Double,
        agreeableness: Double,
        neuroticism: Double,
        confidence: Double
    ) {
        self.openness = openness
        self.conscientiousness = conscientiousness
        self.extraversion = extraversion
        self.agreeableness = agreeableness
        self.neuroticism = neuroticism
        self.confidence = confidence
        self.lastAnalysisDate = Date()

        // Derive personality type from dominant trait
        let traits: [(PersonalityType, Double)] = [
            (.explorer, openness),
            (.curator, conscientiousness),
            (.enthusiast, extraversion),
            (.analyzer, agreeableness),
            (.balanced, 0.5),
        ]
        if let dominant = traits.max(by: { $0.1 < $1.1 }) {
            personalityType = dominant.0
        }
    }
}
