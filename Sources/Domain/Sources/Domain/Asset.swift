import Foundation
import SwiftUI

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

        /// Get a SwiftUI Color for this mood
        public var color: Color {
            switch self {
            case .energetic: .orange
            case .relaxed: .blue
            case .happy: .yellow
            case .melancholic: .purple
            case .focused: .green
            case .romantic: .pink
            case .angry: .red
            case .neutral: .gray
            }
        }

        /// Get system icon name
        public var systemIcon: String {
            switch self {
            case .energetic: "bolt.fill"
            case .relaxed: "leaf.fill"
            case .happy: "sun.max.fill"
            case .melancholic: "cloud.rain.fill"
            case .focused: "target"
            case .romantic: "heart.fill"
            case .angry: "flame.fill"
            case .neutral: "circle.fill"
            }
        }
    }
}
