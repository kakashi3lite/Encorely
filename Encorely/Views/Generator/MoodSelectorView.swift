import SwiftUI

/// Lets the user pick a mood to generate a new mixtape.
/// Displays all moods in a grid with icons and colors.
struct MoodSelectorView: View {
    @Environment(MoodEngine.self) private var moodEngine
    @State private var selectedMood: Mood?

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                moodGrid
            }
            .padding()
        }
        .navigationTitle("Generate Mixtape")
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("How are you feeling?")
                .font(.title2.bold())

            Text("Pick a mood and we'll create a mixtape just for you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Current detected mood hint
            if moodEngine.moodConfidence > 0.5 {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("We think you're feeling \(moodEngine.currentMood.rawValue.lowercased())")
                }
                .font(.caption)
                .foregroundStyle(.purple)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Grid

    private var moodGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Mood.allCases) { mood in
                NavigationLink(value: AppDestination.generatorResult(mood: mood)) {
                    MoodCard(mood: mood, isDetected: mood == moodEngine.currentMood)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Mood Card

private struct MoodCard: View {
    let mood: Mood
    let isDetected: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: mood.systemIcon)
                .font(.system(size: 36))
                .foregroundStyle(.white)

            Text(mood.rawValue)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(mood.color.gradient, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            if isDetected {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(8)
            }
        }
        .accessibilityLabel("\(mood.rawValue) mood")
        .accessibilityHint("Double tap to generate a \(mood.rawValue.lowercased()) mixtape")
    }
}
