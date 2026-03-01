import SwiftUI

/// Real-time audio spectrum visualizer using Canvas.
/// Draws vertical bars representing frequency band magnitudes.
struct AudioVisualizationView: View {
    @Environment(MoodEngine.self) private var moodEngine

    /// Spectrum data from the audio analyzer. Falls back to demo data.
    @State private var spectrumData: [Float] = AudioVisualizationView.demoSpectrum()

    /// Controls the demo animation lifecycle.
    @State private var isAnimating = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            Canvas { context, size in
                drawSpectrum(context: context, size: size)
            }
        }
        .background(Color.black.opacity(0.05))
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
        .task(id: isAnimating) {
            guard isAnimating else { return }
            await runDemoAnimation()
        }
        .accessibilityLabel("Audio spectrum visualization")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Drawing

    private func drawSpectrum(context: GraphicsContext, size: CGSize) {
        let bands = spectrumData.count
        guard bands > 0 else { return }

        let barWidth = size.width / CGFloat(bands) * 0.8
        let spacing = size.width / CGFloat(bands) * 0.2
        let color = moodEngine.currentMood.color

        for (index, magnitude) in spectrumData.enumerated() {
            let x = CGFloat(index) * (barWidth + spacing) + spacing / 2
            let height = CGFloat(magnitude) * size.height
            let y = size.height - height

            let rect = CGRect(x: x, y: y, width: barWidth, height: height)
            let roundedRect = RoundedRectangle(cornerRadius: barWidth / 3)
                .path(in: rect)

            let opacity = 0.4 + Double(magnitude) * 0.6
            context.fill(roundedRect, with: .color(color.opacity(opacity)))
        }
    }

    // MARK: - Demo Animation

    /// Async demo animation that replaces the Timer-based approach
    /// to avoid Sendable closure warnings in Swift 6.
    @MainActor
    private func runDemoAnimation() async {
        while isAnimating && !Task.isCancelled {
            spectrumData = spectrumData.map { value in
                let delta = Float.random(in: -0.08...0.08)
                return min(1.0, max(0.05, value + delta))
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Generates initial random spectrum for demo mode.
    private static func demoSpectrum() -> [Float] {
        (0..<32).map { i in
            let center: Float = 10.0
            let distance = abs(Float(i) - center)
            let base = max(0.1, 0.7 - distance * 0.03)
            return base + Float.random(in: -0.05...0.05)
        }
    }
}
