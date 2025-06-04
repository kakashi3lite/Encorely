public enum Mood: String, Codable {
    case energetic
    case relaxed
    case happy
    case melancholic
    case focused
    case neutral
    
    var iconName: String {
        switch self {
        case .energetic: return "bolt.fill"
        case .relaxed: return "leaf.fill"
        case .happy: return "sun.max.fill"
        case .melancholic: return "cloud.rain.fill"
        case .focused: return "target"
        case .neutral: return "circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .energetic: return .orange
        case .relaxed: return .mint
        case .happy: return .yellow
        case .melancholic: return .blue
        case .focused: return .purple
        case .neutral: return .gray
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

public struct AudioFeatures: Codable {
    public let spectralCentroid: Float
    public let spectralRolloff: Float
    public let spectralFlux: Float
    public let zeroCrossingRate: Float
    public let rms: Float
    public let tempo: Float?
    public let mood: Mood
    
    public init(
        spectralCentroid: Float,
        spectralRolloff: Float,
        spectralFlux: Float,
        zeroCrossingRate: Float,
        rms: Float,
        tempo: Float? = nil,
        mood: Mood = .neutral
    ) {
        self.spectralCentroid = spectralCentroid
        self.spectralRolloff = spectralRolloff
        self.spectralFlux = spectralFlux
        self.zeroCrossingRate = zeroCrossingRate
        self.rms = rms
        self.tempo = tempo
        self.mood = mood
    }
}

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
    public let dominantMood: Mood
    public let personalityTraits: [PersonalityType]
    
    public init(features: AudioFeatures, dominantMood: Mood, personalityTraits: [PersonalityType]) {
        self.features = features
        self.dominantMood = dominantMood
        self.personalityTraits = personalityTraits
    }
}
