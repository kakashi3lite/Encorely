import SwiftUI

/// A simpler waveform-style visualization for inline use.
/// Shows a horizontal waveform with mood-colored strokes.
struct SpectrumView: View {
    let data: [Float]
    let moodColor: Color

    init(data: [Float] = [], moodColor: Color = .blue) {
        self.data = data.isEmpty ? SpectrumView.defaultData : data
        self.moodColor = moodColor
    }

    var body: some View {
        Canvas { context, size in
            guard !data.isEmpty else { return }

            let stepX = size.width / CGFloat(data.count - 1)
            let midY = size.height / 2

            var path = Path()
            for (index, value) in data.enumerated() {
                let x = CGFloat(index) * stepX
                let amplitude = CGFloat(value) * midY
                let y = midY - amplitude

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            // Mirror below center line
            for (index, value) in data.enumerated().reversed() {
                let x = CGFloat(index) * stepX
                let amplitude = CGFloat(value) * midY
                let y = midY + amplitude
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.closeSubpath()

            context.fill(path, with: .linearGradient(
                Gradient(colors: [moodColor.opacity(0.6), moodColor.opacity(0.1)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            // Stroke center line
            var centerPath = Path()
            for (index, value) in data.enumerated() {
                let x = CGFloat(index) * stepX
                let y = midY - CGFloat(value) * midY
                if index == 0 { centerPath.move(to: CGPoint(x: x, y: y)) }
                else { centerPath.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(centerPath, with: .color(moodColor), lineWidth: 2)
        }
        .accessibilityHidden(true)
    }

    private static let defaultData: [Float] = (0..<40).map { i in
        0.3 + 0.3 * sin(Float(i) * 0.3)
    }
}
