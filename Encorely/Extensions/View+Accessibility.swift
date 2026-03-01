import SwiftUI

/// Accessibility helpers for consistent VoiceOver and Dynamic Type support.
extension View {
    /// Adds a VoiceOver label and hint in one call.
    func accessibleLabel(_ label: String, hint: String = "") -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint.isEmpty ? Text(verbatim: "") : Text(hint))
    }

    /// Hides the view from VoiceOver when it's purely decorative.
    func decorative() -> some View {
        self.accessibilityHidden(true)
    }
}
