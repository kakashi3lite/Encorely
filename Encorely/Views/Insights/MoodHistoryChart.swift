import SwiftUI

/// Visualizes mood snapshots over time as colored dots on a timeline.
struct MoodHistoryChart: View {
    let snapshots: [MoodSnapshot]

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard !snapshots.isEmpty else { return }

                let padding: CGFloat = 8
                let usableWidth = size.width - padding * 2
                let usableHeight = size.height - padding * 2
                let moods = Mood.allCases
                let moodStep = usableHeight / CGFloat(moods.count)

                // Draw horizontal mood lanes
                for (index, mood) in moods.enumerated() {
                    let y = padding + CGFloat(index) * moodStep + moodStep / 2

                    // Lane line
                    var lane = Path()
                    lane.move(to: CGPoint(x: padding, y: y))
                    lane.addLine(to: CGPoint(x: size.width - padding, y: y))
                    context.stroke(lane, with: .color(.gray.opacity(0.15)), lineWidth: 1)

                    // Lane label
                    let text = Text(mood.rawValue)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    context.draw(context.resolve(text), at: CGPoint(x: padding + 2, y: y - 8))
                }

                // Draw dots for each snapshot
                let timeRange = snapshotTimeRange()
                for snapshot in snapshots {
                    guard let moodIndex = moods.firstIndex(of: snapshot.mood) else { continue }

                    let x = xPosition(
                        for: snapshot.timestamp,
                        in: timeRange,
                        width: usableWidth,
                        padding: padding
                    )
                    let y = padding + CGFloat(moodIndex) * moodStep + moodStep / 2

                    let dotSize: CGFloat = 8
                    let rect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(Circle().path(in: rect), with: .color(snapshot.mood.color))
                }
            }
        }
        .accessibilityLabel("Mood history chart with \(snapshots.count) data points")
    }

    private func snapshotTimeRange() -> ClosedRange<TimeInterval> {
        guard let first = snapshots.last?.timestamp, let last = snapshots.first?.timestamp else {
            return 0...1
        }
        let start = first.timeIntervalSinceReferenceDate
        let end = last.timeIntervalSinceReferenceDate
        return start...(end == start ? start + 1 : end)
    }

    private func xPosition(
        for date: Date,
        in range: ClosedRange<TimeInterval>,
        width: CGFloat,
        padding: CGFloat
    ) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate
        let normalized = (t - range.lowerBound) / (range.upperBound - range.lowerBound)
        return padding + CGFloat(normalized) * width
    }
}
