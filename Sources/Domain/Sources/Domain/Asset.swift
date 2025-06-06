import SwiftUI
import Foundation

/// Namespace for asset-related types
public enum Asset {
    /// Mood-based colors
    public enum MoodColor: String, CaseIterable {
        case energetic = "Energetic"
        case relaxed = "Relaxed"
        case happy = "Happy"
        case melancholic = "Melancholic"
        case focused = "Focused"
        case romantic = "Romantic"
        case angry = "Angry"
        case neutral = "Neutral"
        
        /// Get a UIColor for this mood
        public var uiColor: UIColor {
            guard let color = UIColor(named: "Mood/\(rawValue)") else {
                assertionFailure("Missing mood color asset: \(rawValue)")
                return .clear
            }
            return color
        }
        
        /// Get a SwiftUI Color for this mood
        public var color: Color {
            switch self {
            case .energetic: return .orange
            case .relaxed: return .blue
            case .happy: return .yellow
            case .melancholic: return .purple
            case .focused: return .green
            case .romantic: return .pink
            case .angry: return .red
            case .neutral: return .gray
            }
        }
        
        /// Get system icon name
        public var systemIcon: String {
            switch self {
            case .energetic: return "bolt.fill"
            case .relaxed: return "leaf.fill"
            case .happy: return "sun.max.fill"
            case .melancholic: return "cloud.rain.fill"
            case .focused: return "target"
            case .romantic: return "heart.fill"
            case .angry: return "flame.fill"
            case .neutral: return "circle.fill"
            }
        }
    }
}
