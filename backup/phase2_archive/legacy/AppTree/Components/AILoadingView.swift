import SwiftUI

struct AILoadingView: View {
    let message: String
    @State private var dotCount = 0

    init(message: String = "AI is analyzing") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 16) {
            // Animated icon
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                    .frame(width: 48, height: 48)

                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.accentColor, lineWidth: 4)
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(dotCount * 120))

                Image(systemName: "brain")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }

            // Loading text with animated dots
            Text("\(message)\(String(repeating: ".", count: dotCount % 4))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                dotCount = 8
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message). Loading")
        .accessibilityAddTraits(.updatesFrequently)
    }
}
