import SwiftUI

/// Maps mood values to named colors from the asset catalog.
extension Color {
    /// Returns the asset catalog color matching a given mood.
    static func forMood(_ mood: Mood) -> Color {
        switch mood {
        case .happy:       Color("Happy", bundle: .main)
        case .energetic:   Color("Energetic", bundle: .main)
        case .relaxed:     Color("Relaxed", bundle: .main)
        case .melancholic: Color("Melancholic", bundle: .main)
        case .focused:     Color("Focused", bundle: .main)
        case .angry:       Color("Angry", bundle: .main)
        }
    }
}
