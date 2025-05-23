import Foundation
import SwiftUI

/// Enum representing different mood states the app can detect and use
public enum Mood: String, Codable, CaseIterable {
    case energetic = "Energetic"
    case relaxed = "Relaxed"
    case happy = "Happy"
    case melancholic = "Melancholic"
    case focused = "Focused"
    case romantic = "Romantic"
    case angry = "Angry"
    case neutral = "Neutral"
    
    /// Keywords associated with each mood
    public var keywords: [String] {
        switch self {
        case .energetic: return ["upbeat", "exciting", "energetic", "dance", "party", "workout"]
        case .relaxed: return ["calm", "chill", "peaceful", "ambient", "meditation"]
        case .happy: return ["happy", "joyful", "uplifting", "positive", "fun"]
        case .melancholic: return ["sad", "melancholy", "emotional", "reflective"]
        case .focused: return ["focus", "concentration", "study", "work"]
        case .romantic: return ["love", "romantic", "passion", "intimate"]
        case .angry: return ["angry", "intense", "rage", "aggressive"]
        case .neutral: return ["neutral", "balanced", "moderate"]
        }
    }
    
    /// Returns a color associated with each mood
    public var color: Color {
        switch self {
        case .energetic: return .orange
        case .relaxed: return .blue
        case .happy: return .yellow
        case .melancholic: return .purple
        case .focused: return .gray
        case .romantic: return .pink
        case .angry: return .red
        case .neutral: return .white
        }
    }
    
    /// Returns a description for each mood
    public var description: String {
        switch self {
        case .energetic: return "High-energy, upbeat music"
        case .relaxed: return "Calm, peaceful melodies"
        case .happy: return "Positive, joyful tunes" 
        case .melancholic: return "Emotional, reflective songs"
        case .focused: return "Music for concentration"
        case .romantic: return "Love songs and intimate melodies"
        case .angry: return "Intense, powerful tracks"
        case .neutral: return "Balanced, versatile music"
        }
    }
}

/// Enum representing different personality types
public enum PersonalityType: String, Codable, CaseIterable {
    case analyzer = "Analyzer"   // Values technical details and control
    case explorer = "Explorer"   // Values discovery and variety
    case planner = "Planner"     // Values organization and quality
    case creative = "Creative"   // Values deep dives and expertise
    case balanced = "Balanced"   // Neutral personality type
    
    /// Returns a theme color associated with each personality type
    public var themeColor: Color {
        switch self {
        case .analyzer: return .blue
        case .explorer: return .purple
        case .planner: return .orange
        case .creative: return .green
        case .balanced: return .gray
        }
    }
    
    /// Keywords associated with each personality type
    public var keywords: [String] {
        switch self {
        case .analyzer: return ["technical", "detailed", "analytical", "precise", "control"]
        case .explorer: return ["discover", "variety", "adventure", "new", "diverse"]
        case .planner: return ["organize", "quality", "structure", "curate", "plan"]
        case .creative: return ["artistic", "innovative", "expressive", "imaginative"]
        case .balanced: return ["neutral", "balanced", "moderate", "adaptable"]
        }
    }
    
    /// Description of each personality type
    public var description: String {
        switch self {
        case .analyzer: return "Values technical details and precise control"
        case .explorer: return "Values discovery and variety in music"
        case .planner: return "Values organization and quality content"
        case .creative: return "Values artistic expression and innovation"
        case .balanced: return "Values balanced and adaptable experiences"
        }
    }
}
