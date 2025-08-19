import SwiftUI

public struct NoirGlass: ViewModifier {
    @Environment(\..accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat
    let strokeWidth: CGFloat
    let backdropOpacity: Double     // extra darkening behind material
    let noiseOpacity: Double

    public func body(content: Content) -> some View {
        content
            .padding(0)
            .background(backgroundLayer)
            .overlay(strokeLayer)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: NoirPalette.shadow, radius: 24, x: 0, y: 12)
    }

    @ViewBuilder private var backgroundLayer: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            shape
                .fill(NoirPalette.background)
                .overlay(shape.fill(NoirPalette.surfaceTint.opacity(0.95)))
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(NoirPalette.background.opacity(backdropOpacity))
                .overlay(noiseOverlay.opacity(noiseOpacity).blendMode(.overlay))
        }
    }

    private var strokeLayer: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [NoirPalette.strokeHi, NoirPalette.strokeLo],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: strokeWidth
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(NoirPalette.highlight, lineWidth: 1)
                    .blur(radius: 1)
                    .opacity(0.6)
            )
    }

    @ViewBuilder private var noiseOverlay: some View {
        #if canImport(UIKit)
        if let uiImage = UIImage(named: "noise_512") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .allowsHitTesting(false)
                .clipped()
        } else {
            Color.white.opacity(0.02)
        }
        #else
        Color.white.opacity(0.02)
        #endif
    }
}

public extension View {
    func noirGlass(
        cornerRadius: CGFloat = 24,
        strokeWidth: CGFloat = 1,
        backdropOpacity: Double = 0.28,
        noiseOpacity: Double = 0.06
    ) -> some View {
        modifier(NoirGlass(
            cornerRadius: cornerRadius,
            strokeWidth: strokeWidth,
            backdropOpacity: backdropOpacity,
            noiseOpacity: noiseOpacity
        ))
    }
}
