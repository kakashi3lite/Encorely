import SwiftUI
import Combine

/// Manages smooth transitions between mood and personality colors
class ColorTransitionManager: ObservableObject {
    @Published private(set) var currentMoodColor: Asset.MoodColor = .happy
    @Published private(set) var currentPersonalityColor: Asset.PersonalityColor = .enthusiast
    
    private var cancellables = Set<AnyCancellable>()
    
    /// Duration for color transitions
    var transitionDuration: Double = 0.3
    
    /// Transition to a new mood color
    /// - Parameter mood: The target mood color
    /// - Parameter completion: Optional completion handler
    func transition(to mood: Asset.MoodColor, completion: (() -> Void)? = nil) {
        withAnimation(.easeInOut(duration: transitionDuration)) {
            self.currentMoodColor = mood
        }
        
        if let completion = completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration) {
                completion()
            }
        }
    }
    
    /// Update personality theme
    /// - Parameter personality: The target personality color
    func updatePersonality(_ personality: Asset.PersonalityColor) {
        withAnimation(.easeInOut(duration: transitionDuration)) {
            self.currentPersonalityColor = personality
        }
    }
    
    /// Get interpolated color between two moods
    /// - Parameters:
    ///   - from: Starting mood color
    ///   - to: Target mood color
    ///   - progress: Transition progress (0-1)
    /// - Returns: Interpolated SwiftUI Color
    func interpolatedColor(from: Asset.MoodColor, to: Asset.MoodColor, progress: Double) -> Color {
        let fromColor = from.color
        let toColor = to.color
        return fromColor.interpolateTo(toColor, progress: progress)
    }
}
