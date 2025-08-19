import SwiftUI

public struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content
    public init(cornerRadius: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    public var body: some View {
        content
            .padding(16)
            .noirGlass(cornerRadius: cornerRadius)
    }
}

public struct GlassButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(NoirPalette.onGlass)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [
                        NoirPalette.surfaceTint.opacity(configuration.isPressed ? 0.9 : 0.75),
                        NoirPalette.surfaceTint.opacity(configuration.isPressed ? 0.75 : 0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .noirGlass(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NoirPalette.accent.opacity(configuration.isPressed ? 0.8 : 0.4), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

public struct GlassToolbar: View {
    public let title: String
    public init(_ title: String) { self.title = title }
    public var body: some View {
        HStack {
            Text(title)
                .font(.title3.bold())
                .foregroundColor(NoirPalette.onGlass)
            Spacer()
        }
        .padding(12)
        .noirGlass(cornerRadius: 20, backdropOpacity: 0.22)
    }
}
