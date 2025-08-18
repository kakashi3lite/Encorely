import Foundation
import SwiftUI

public enum PersonalityType: String, Codable, CaseIterable {
    case analyzer = "Analyzer"
    case explorer = "Explorer"
    case curator = "Curator"
    case enthusiast = "Enthusiast"
    case social = "Social"
    case ambient = "Ambient"
    case balanced = "Balanced"

    public var themeColor: Color {
        switch self {
        case .analyzer: .blue
        case .explorer: .purple
        case .curator: .orange
        case .enthusiast: .green
        case .social: .teal
        case .ambient: .mint
        case .balanced: .gray
        }
    }
}

public enum SharedMood: String, Codable {
    case energetic
    case relaxed
    case happy
    case melancholic
    case focused
    case neutral

    public var iconName: String {
        switch self {
        case .energetic: "bolt.fill"
        case .relaxed: "leaf.fill"
        case .happy: "sun.max.fill"
        case .melancholic: "cloud.rain.fill"
        case .focused: "target"
        case .neutral: "circle.fill"
        }
    }

    public var color: Color {
        switch self {
        case .energetic: .orange
        case .relaxed: .mint
        case .happy: .yellow
        case .melancholic: .blue
        case .focused: .purple
        case .neutral: .gray
        }
    }
}

public enum AudioProcessingError: Error {
    case initializationFailed
    case bufferCreationFailed
    case processingFailed
    case invalidBufferFormat
    case resourceUnavailable
}

// AudioFeatures is defined in App/Consolidated/AudioFeatures.swift

public enum ServiceState {
    case initializing
    case ready
    case reducedFunctionality
    case error
}

public enum ResourceUtilization {
    case normal
    case heavy
    case critical
}

public struct MixtapeGenerationOptions {
    public let duration: TimeInterval
    public let includeMoodTransitions: Bool
    public let personalityInfluence: Double

    public init(duration: TimeInterval, includeMoodTransitions: Bool, personalityInfluence: Double) {
        self.duration = duration
        self.includeMoodTransitions = includeMoodTransitions
        self.personalityInfluence = personalityInfluence
    }
}

public struct AudioAnalysisResult {
    public let features: AudioFeatures
    public let dominantMood: SharedMood
    public let personalityTraits: [PersonalityType]

    public init(features: AudioFeatures, dominantMood: SharedMood, personalityTraits: [PersonalityType]) {
        self.features = features
        self.dominantMood = dominantMood
        self.personalityTraits = personalityTraits
    }
}
