import SwiftUI

/// Main analysis tab showing the audio visualizer and current mood detection.
struct AnalysisView: View {
    @Environment(MoodEngine.self) private var moodEngine
    @Environment(AudioPlaybackService.self) private var playbackService

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current mood display
                currentMoodSection

                // Audio visualization
                visualizationSection

                // Mood distribution chart
                distributionSection
            }
            .padding()
        }
        .navigationTitle("Analyze")
    }

    // MARK: - Current Mood

    private var currentMoodSection: some View {
        VStack(spacing: 12) {
            Image(systemName: moodEngine.currentMood.systemIcon)
                .font(.system(size: 48))
                .foregroundStyle(moodEngine.currentMood.color)
                .accessibilityHidden(true)

            Text(moodEngine.currentMood.rawValue)
                .font(.title.bold())

            if moodEngine.moodConfidence > 0 {
                Text("\(Int(moodEngine.moodConfidence * 100))% confidence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current mood: \(moodEngine.currentMood.rawValue)")
    }

    // MARK: - Visualization

    private var visualizationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Audio Spectrum")
                .font(.headline)

            AudioVisualizationView()
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Distribution

    private var distributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood Distribution")
                .font(.headline)

            ForEach(Mood.allCases) { mood in
                HStack(spacing: 8) {
                    Image(systemName: mood.systemIcon)
                        .foregroundStyle(mood.color)
                        .frame(width: 24)

                    Text(mood.rawValue)
                        .font(.caption)
                        .frame(width: 80, alignment: .leading)

                    GeometryReader { geo in
                        let percentage = moodEngine.moodDistribution[mood] ?? 0
                        RoundedRectangle(cornerRadius: 4)
                            .fill(mood.color.opacity(0.3))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(mood.color)
                                    .frame(width: geo.size.width * CGFloat(percentage))
                            }
                    }
                    .frame(height: 12)

                    Text("\(Int((moodEngine.moodDistribution[mood] ?? 0) * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
