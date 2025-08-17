// filepath: Sources/Kits/GlassUI/GlassCard.swift
import SwiftUI

public struct GlassCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let content: Content

    public init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        Group {
            if UIAccessibility.isReduceTransparencyEnabled {
                content
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            } else {
                content
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                            .blendMode(.overlay)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
            }
        }
    }
}
