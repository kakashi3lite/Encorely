import SwiftUI

extension Color {
    /// Modifies the saturation of the color by the given amount
    func saturated(by amount: Double) -> Color {
        guard let components = cgColor?.components else { return self }

        // Convert RGB to HSV
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if os(iOS)
            UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #else
            NSColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #endif

        // Modify saturation
        s *= CGFloat(amount)
        s = max(0, min(1, s))

        #if os(iOS)
            return Color(UIColor(hue: h, saturation: s, brightness: b, alpha: a))
        #else
            return Color(NSColor(hue: h, saturation: s, brightness: b, alpha: a))
        #endif
    }

    /// Modifies the brightness of the color by the given amount
    func brightened(by amount: Double) -> Color {
        guard let components = cgColor?.components else { return self }

        // Convert RGB to HSV
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if os(iOS)
            UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #else
            NSColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #endif

        // Modify brightness
        b *= CGFloat(amount)
        b = max(0, min(1, b))

        #if os(iOS)
            return Color(UIColor(hue: h, saturation: s, brightness: b, alpha: a))
        #else
            return Color(NSColor(hue: h, saturation: s, brightness: b, alpha: a))
        #endif
    }
}
