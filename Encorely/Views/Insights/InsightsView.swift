import SwiftData
import SwiftUI

/// Shows mood history trends and listening insights.
struct InsightsView: View {
    @Query(sort: \MoodSnapshot.timestamp, order: .reverse) private var snapshots: [MoodSnapshot]
    @Environment(MoodEngine.self) private var moodEngine
    @Environment(PersonalityEngine.self) private var personalityEngine

    /// Factory for NavigationStack destinations (avoids @Query init synthesis issue).
    static func asDestination() -> some View {
        InsightsView()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                personalitySection
                moodHistorySection
                statsSection
            }
            .padding()
        }
        .navigationTitle("Insights")
    }

    // MARK: - Personality

    private var personalitySection: some View {
        VStack(spacing: 12) {
            Text("Your Music Personality")
                .font(.headline)

            Text(personalityEngine.currentPersonality.rawValue)
                .font(.title.bold())
                .foregroundStyle(personalityEngine.currentPersonality.themeColor)

            Text(personalityEngine.currentPersonality.typeDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if personalityEngine.confidence > 0 {
                Text("Confidence: \(Int(personalityEngine.confidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Mood History

    private var moodHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Moods")
                .font(.headline)

            if snapshots.isEmpty {
                Text("No mood data yet. Play some music to see your mood trends.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                MoodHistoryChart(snapshots: Array(snapshots.prefix(30)))
                    .frame(height: 160)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Listening Stats")
                .font(.headline)

            let moodCounts = Dictionary(grouping: snapshots, by: \.mood)
            ForEach(Mood.allCases) { mood in
                let count = moodCounts[mood]?.count ?? 0
                if count > 0 {
                    HStack {
                        Image(systemName: mood.systemIcon)
                            .foregroundStyle(mood.color)
                        Text(mood.rawValue)
                        Spacer()
                        Text("\(count) sessions")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
