import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct GlassCard<Content: View>: View {
    private let content: Content
    private let cornerRadius: CGFloat
    private let tint: Color

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(cornerRadius: CGFloat = 16, tint: Color = Color.white.opacity(0.25), @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.content = content()
    }

    private var fallbackBackground: Color {
        #if os(iOS)
        return Color(UIColor.systemBackground)
        #elseif os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color.black.opacity(0.1)
        #endif
    }

    public var body: some View {
        ZStack {
            cardBackground
            
            content
                .padding(16)
        }
        .compositingGroup()
        .shadow(
            color: reduceMotion ? .clear : .black.opacity(0.08),
            radius: 12, x: 0, y: 6
        )
        .shadow(
            color: reduceMotion ? .clear : .black.opacity(0.04),
            radius: 2, x: 0, y: 1
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Glass card")
    }
    
    @ViewBuilder
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        if reduceTransparency || differentiateWithoutColor {
            shape
                .fill(fallbackBackground)
                .overlay(
                    shape.strokeBorder(
                        differentiateWithoutColor ? Color.primary.opacity(0.3) : Color.primary.opacity(0.12),
                        lineWidth: differentiateWithoutColor ? 2 : 1
                    )
                )
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                        .blendMode(.overlay)
                )
                .background(
                    Group {
                        if !reduceMotion {
                            shape
                                .fill(tint)
                                .blur(radius: 30)
                        }
                    }
                )
        }
    }
}

#if DEBUG
struct GlassCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Encorely")
                        .font(.headline)
                    Text("Premium glass card with fallbacks.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .padding()
        .background(
            LinearGradient(colors: [.purple, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}
#endif
