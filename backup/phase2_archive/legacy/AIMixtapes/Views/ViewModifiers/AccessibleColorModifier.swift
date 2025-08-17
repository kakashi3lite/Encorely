import SwiftUI

struct AccessibleColorModifier: ViewModifier {
    let baseColor: Color
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityContrast) var contrast

    func body(content: Content) -> some View {
        content.foregroundColor(getAccessibleColor())
    }

    private func getAccessibleColor() -> Color {
        // Adjust color for high contrast mode
        if contrast == .high {
            return colorScheme == .dark ?
                makeColorHigherContrast(baseColor, against: .black) :
                makeColorHigherContrast(baseColor, against: .white)
        }
        return baseColor
    }

    private func makeColorHigherContrast(_ color: Color, against background: Color) -> Color {
        // Convert to RGB components
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Adjust color components for better contrast
        if background == .black {
            // Make colors brighter against dark background
            red = min(1, red * 1.3)
            green = min(1, green * 1.3)
            blue = min(1, blue * 1.3)
        } else {
            // Make colors darker against light background
            red = max(0, red * 0.7)
            green = max(0, green * 0.7)
            blue = max(0, blue * 0.7)
        }

        return Color(UIColor(red: red, green: green, blue: blue, alpha: alpha))
    }
}

extension View {
    func accessibleColor(_ color: Color) -> some View {
        modifier(AccessibleColorModifier(baseColor: color))
    }
}
