//
//  MoodView.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import SwiftUI

struct MoodView: View {
    @StateObject private var colorTransitionManager = ColorTransitionManager()
    @ObservedObject var moodEngine: MoodEngine

    var body: some View {
        VStack(spacing: 20) {
            // Mood Title with accessibility
            Text(moodEngine.currentMood.rawValue)
                .scalableText(style: .largeTitle, weight: .bold)
                .accessibleColor(moodEngine.currentMood.color)
                .accessibilityLabel("Current mood")
                .accessibilityValue(moodEngine.currentMood.rawValue)
                .accessibilityAddTraits(.isHeader)

            // Mood Intensity Indicator with accessibility
            CircularProgressView(progress: moodEngine.moodIntensity)
                .frame(width: 150, height: 150)
                .accessibleColor(moodEngine.currentMood.color)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Mood intensity")
                .accessibilityValue("\(Int(moodEngine.moodIntensity * 100))%")
                .accessibilityHint("Shows how strongly the current mood is detected")
                .accessibilityAddTraits(.updatesFrequently)

            // Mood Selection Grid with dynamic layout
            VStack(alignment: .leading) {
                Text("Select Your Mood")
                    .scalableText(style: .headline)
                    .padding(.horizontal)
                    .accessibilityHidden(true)

                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(Asset.MoodColor.allCases, id: \.rawValue) { mood in
                        MoodCard(
                            mood: mood,
                            isSelected: mood == moodEngine.currentMood,
                            onSelect: { selectMood(mood) }
                        )
                        .accessibleColor(moodEngine.currentMood.color)
                    }
                }
                .padding()
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Mood options")
                .accessibilityHint("Select the mood that best matches how you feel")
            }
        }
        .animation(.easeInOut, value: moodEngine.currentMood)
        .onChange(of: moodEngine.currentMood) { newMood in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                colorTransitionManager.transition(to: newMood)
            }

            // Haptic feedback
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // Dynamic grid columns based on size class
    private var gridColumns: [GridItem] {
        let count = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
        return Array(repeating: GridItem(.flexible()), count: count)
    }

    private func selectMood(_ mood: Asset.MoodColor) {
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        moodEngine.updateMood(mood)
    }
}

// MARK: - Supporting Views

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .animation(.easeInOut, value: progress)
            .accessibilityHidden(true)
    }
}

struct MoodCard: View {
    let mood: Asset.MoodColor
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack {
                Text(mood.rawValue)
                    .scalableText(style: .headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(mood.color)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: isSelected ? 5 : 0)
                    .scaleEffect(isSelected ? 1.05 : 1)
            }
        }
        .buttonStyle(MoodButtonStyle())
        .accessibleTouchTarget(minSize: 60)
        .accessibilityLabel("\(mood.rawValue) mood")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to \(isSelected ? "change from" : "select") \(mood.rawValue) mood")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

struct MoodButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}
