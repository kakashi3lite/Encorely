import SwiftUI

/// View modifier that applies mood-based colors to views
struct MoodColorModifier: ViewModifier {
    @ObservedObject private var transitionManager: ColorTransitionManager
    let colorType: ColorType
    
    enum ColorType {
        case background
        case foreground
        case accent
    }
    
    init(transitionManager: ColorTransitionManager, colorType: ColorType = .background) {
        self.transitionManager = transitionManager
        self.colorType = colorType
    }
    
    func body(content: Content) -> some View {
        content
            .background(colorType == .background ? moodColor : nil)
            .foregroundColor(colorType == .foreground ? moodColor : nil)
            .accentColor(colorType == .accent ? moodColor : nil)
    }
    
    private var moodColor: Color {
        transitionManager.currentMoodColor.color
    }
}

extension View {
    /// Apply mood-based coloring to a view
    func moodColored(_ manager: ColorTransitionManager, as type: MoodColorModifier.ColorType = .background) -> some View {
        modifier(MoodColorModifier(transitionManager: manager, colorType: type))
    }
    
    /// Apply personality-based theming to a view
    func personalityThemed(_ manager: ColorTransitionManager) -> some View {
        let color = manager.currentPersonalityColor.color
        return self.tint(color)
    }
}
