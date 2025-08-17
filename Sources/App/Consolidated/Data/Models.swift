// filepath: Sources/App/Consolidated/Data/Models.swift
import Foundation

#if canImport(SwiftData)
import SwiftData

@available(iOS 17, *)
@Model public final class UserPersona {
    public var openness: Double
    public var conscientiousness: Double
    public var extraversion: Double
    public var agreeableness: Double
    public var neuroticism: Double
    public var updatedAt: Date

    public init(openness: Double, conscientiousness: Double, extraversion: Double, agreeableness: Double, neuroticism: Double, updatedAt: Date = .now) {
        self.openness = openness
        self.conscientiousness = conscientiousness
        self.extraversion = extraversion
        self.agreeableness = agreeableness
        self.neuroticism = neuroticism
        self.updatedAt = updatedAt
    }
}

@available(iOS 17, *)
@Model public final class MoodSample {
    public enum Source: String, Codable { case face, sound, fusion }
    public var ts: Date
    public var valence: Double
    public var arousal: Double
    public var source: String

    public init(ts: Date = .now, valence: Double, arousal: Double, source: String) {
        self.ts = ts
        self.valence = valence
        self.arousal = arousal
        self.source = source
    }
}

@available(iOS 17, *)
@Model public final class PlayEvent {
    public enum Action: String, Codable { case skip, complete, like }
    public var ts: Date
    public var trackID: String
    public var action: String

    public init(ts: Date = .now, trackID: String, action: String) {
        self.ts = ts
        self.trackID = trackID
        self.action = action
    }
}
#endif
