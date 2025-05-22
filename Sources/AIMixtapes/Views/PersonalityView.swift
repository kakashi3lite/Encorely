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
                .font(.largeTitle)
                .fontWeight(.bold)
                .personalityThemed(transitionManager)
            
            // Personality Description
            Text(personalityDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
            
            // Personality Selection
            ForEach(Asset.PersonalityColor.allCases, id: \.rawValue) { personality in
                PersonalityCard(
                    personality: personality,
                    isSelected: personality == personalityEngine.currentPersonality
                )
                .onTapGesture {
                    selectPersonality(personality)
                }
            }
        }
        .onChange(of: personalityEngine.currentPersonality) { newPersonality in
            transitionManager.updatePersonality(newPersonality)
        }
        .animation(.easeInOut, value: personalityEngine.currentPersonality)
    }
    
    private var personalityDescription: String {
        switch personalityEngine.currentPersonality {
        case .curator:
            return "You have a refined taste in music and enjoy creating carefully curated playlists."
        case .enthusiast:
            return "You're passionate about music and love discovering new songs and artists."
        case .explorer:
            return "You're always seeking new musical experiences and pushing boundaries."
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
                    .font(.headline)
                Text(personalityTraits)
                    .font(.subheadline)
                    .opacity(0.8)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        }
        .padding()
        .background(personality.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(personality.color, lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(.spring(), value: isSelected)
    }
    
    private var personalityTraits: String {
        switch personality {
        case .curator:
            return "Organized • Selective • Detail-oriented"
        case .enthusiast:
            return "Passionate • Energetic • Social"
        case .explorer:
            return "Adventurous • Creative • Open-minded"
        }
    }
}
