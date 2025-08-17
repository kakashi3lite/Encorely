import Foundation

/// Represents a user's MBTI personality profile and associated musical preferences
public struct MBTIProfile: Codable {
    // MBTI Dimensions
    public let extraversion: Float // Extraversion (1.0) vs Introversion (0.0)
    public let sensing: Float // Sensing (1.0) vs Intuition (0.0)
    public let thinking: Float // Thinking (1.0) vs Feeling (0.0)
    public let judging: Float // Judging (1.0) vs Perceiving (0.0)

    /// Audio feature preferences derived from MBTI dimensions
    public var audioPreferences: AudioPreferences {
        AudioPreferences(
            energy: extraversion * 0.8 + thinking * 0.2, // E/I strongly influences preferred energy levels
            valence: extraversion * 0.4 + feeling * 0.6, // T/F influences emotional content
            tempo: extraversion * 50 + 90, // E: faster, I: slower (90-140 BPM range)
            complexity: intuition * 0.7 + thinking * 0.3, // N/S and T/F influence complexity preference
            structure: judging * 0.8 + sensing * 0.2, // J/P strongly influences structure preference
            variety: perceiving * 0.7 + intuition * 0.3 // P/N influences variety preference
        )
    }

    /// Initialize with dimension scores (0.0 to 1.0)
    public init(extraversion: Float, sensing: Float, thinking: Float, judging: Float) {
        self.extraversion = extraversion
        self.sensing = sensing
        self.thinking = thinking
        self.judging = judging
    }

    // Computed properties for type dimensions
    public var introversion: Float { 1.0 - extraversion }
    public var intuition: Float { 1.0 - sensing }
    public var feeling: Float { 1.0 - thinking }
    public var perceiving: Float { 1.0 - judging }

    /// Get four letter MBTI type (e.g. "INFJ")
    public var typeString: String {
        let e = extraversion > 0.5 ? "E" : "I"
        let s = sensing > 0.5 ? "S" : "N"
        let t = thinking > 0.5 ? "T" : "F"
        let j = judging > 0.5 ? "J" : "P"
        return "\(e)\(s)\(t)\(j)"
    }
}

/// Audio preferences derived from MBTI profile
public struct AudioPreferences: Codable {
    public let energy: Float // 0.0-1.0: Preferred energy level
    public let valence: Float // 0.0-1.0: Preferred emotional valence
    public let tempo: Float // BPM: Preferred tempo
    public let complexity: Float // 0.0-1.0: Preferred musical complexity
    public let structure: Float // 0.0-1.0: Preference for structured vs free-form music
    public let variety: Float // 0.0-1.0: Preference for variety vs consistency

    public init(energy: Float, valence: Float, tempo: Float, complexity: Float, structure: Float, variety: Float) {
        self.energy = min(1.0, max(0.0, energy))
        self.valence = min(1.0, max(0.0, valence))
        self.tempo = min(180.0, max(60.0, tempo))
        self.complexity = min(1.0, max(0.0, complexity))
        self.structure = min(1.0, max(0.0, structure))
        self.variety = min(1.0, max(0.0, variety))
    }
}
