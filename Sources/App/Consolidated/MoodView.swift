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
    @ObservedObject var mcpService = MCPSocketService()

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
                        onSelect: {
                            selectMood(mood)
                            mcpService.emitMoodSelect(type: mood.rawValue)
                        }
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
        }
        .onChange(of: mcpService.moodState) { newState in
            guard let newState,
                  let mood = Asset.MoodColor(rawValue: newState.type),
                  newState.active == true else { return }
            selectMood(mood)
        }
        .onAppear {
            mcpService.connect()
        }
        .onDisappear {
            mcpService.disconnect()
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

private struct MoodCard: View {
    let mood: Asset.MoodColor
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isAnimating = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // Color Circle
                Circle()
                    .fill(mood.color)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? mood.color : Color.clear, lineWidth: 3)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .opacity(isAnimating ? 0 : 1)
                    )

                // Mood Label
                Text(mood.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                // Intensity Bar
                GeometryReader { geometry in
                    Rectangle()
                        .fill(mood.color)
                        .frame(width: geometry.size.width * moodIntensity)
                        .frame(height: 4)
                        .cornerRadius(2)
                }
                .frame(height: 4)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? mood.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onChange(of: isSelected) { newValue in
            if newValue {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7).repeatCount(1)) {
                    isAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isAnimating = false
                }
            }
        }
    }

    private var moodIntensity: CGFloat {
        switch mood {
        case .energetic:
            0.9
        case .relaxed:
            0.6
        case .focused:
            0.8
        case .upbeat:
            0.85
        case .melancholic:
            0.7
        case .balanced:
            0.75
        }
    }
}
