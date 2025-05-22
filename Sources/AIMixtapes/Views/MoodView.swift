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
                .font(.largeTitle)
                .fontWeight(.bold)
                .moodColored(colorTransitionManager, as: .foreground)
                .accessibilityLabel("Current mood: \(moodEngine.currentMood.rawValue)")
            
            // Mood Intensity Indicator with accessibility
            CircularProgressView(progress: moodEngine.moodIntensity)
                .frame(width: 150, height: 150)
                .moodColored(colorTransitionManager, as: .accent)
                .accessibilityLabel("Mood intensity: \(Int(moodEngine.moodIntensity * 100))%")
                .accessibilityValue("\(moodEngine.moodIntensity)")
            
            // Mood Selection Grid with dynamic layout
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(Asset.MoodColor.allCases, id: \.rawValue) { mood in
                    MoodCard(
                        mood: mood,
                        isSelected: mood == moodEngine.currentMood,
                        onSelect: { selectMood(mood) }
                    )
                    .moodColored(colorTransitionManager)
                }
            }
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Mood selection grid")
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
                    .font(.headline)
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
        .accessibilityLabel("\(mood.rawValue) mood")
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MoodButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}
