//
//  PersonalityView.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import SwiftUI

struct PersonalityView: View {
    @StateObject private var transitionManager = ColorTransitionManager()
    @ObservedObject var personalityEngine: PersonalityEngine

    var body: some View {
        VStack(spacing: 24) {
            // Personality Title
            Text(personalityEngine.currentPersonality.rawValue)
                .scalableText(style: .largeTitle, weight: .bold)
                .accessibleColor(personalityEngine.currentPersonality.themeColor)
                .accessibilityLabel("Current personality type")
                .accessibilityValue(personalityEngine.currentPersonality.rawValue)
                .accessibilityAddTraits(.isHeader)

            // Personality Description
            Text(personalityDescription)
                .scalableText(style: .body)
                .multilineTextAlignment(.center)
                .padding()
                .accessibilityLabel("Personality description")

            // Personality Selection
            ForEach(PersonalityType.allCases, id: \.rawValue) { personality in
                PersonalityCard(
                    personality: personality,
                    isSelected: personality == personalityEngine.currentPersonality
                )
                .accessibleTouchTarget(minSize: 80)
                .onTapGesture {
                    selectPersonality(personality)
                }
            }
        }
        .onChange(of: personalityEngine.currentPersonality) { newPersonality in
            transitionManager.updatePersonality(newPersonality)

            // Haptic feedback
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .animation(.easeInOut, value: personalityEngine.currentPersonality)
    }

    private var personalityDescription: String {
        switch personalityEngine.currentPersonality {
        case .curator:
            "You have a refined taste in music and enjoy creating carefully curated playlists."
        case .enthusiast:
            "You're passionate about music and love discovering new songs and artists."
        case .explorer:
            "You're always seeking new musical experiences and pushing boundaries."
        }
    }

    private func selectPersonality(_ personality: Asset.PersonalityColor) {
        personalityEngine.updatePersonality(personality)
    }
}

struct PersonalityCard: View {
    let personality: Asset.PersonalityColor
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(personality.rawValue)
                    .scalableText(style: .headline)
                Text(personalityTraits)
                    .scalableText(style: .subheadline)
                    .opacity(0.8)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .imageScale(.large)
        }
        .padding()
        .background(personality.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(personality.color, lineWidth: isSelected ? 2 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(.spring(), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(personality.rawValue) personality type")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(
            "Double tap to \(isSelected ? "change from" : "select") \(personality.rawValue) personality type")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var personalityTraits: String {
        switch personality {
        case .curator:
            "Organized • Selective • Detail-oriented"
        case .enthusiast:
            "Passionate • Energetic • Social"
        case .explorer:
            "Adventurous • Creative • Open-minded"
        }
    }
}
