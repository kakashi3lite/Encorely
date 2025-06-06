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
    @ObservedObject var mcpService = MCPSocketService()
    @State private var hoveredPersonality: PersonalityType?
    
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
            ForEach(PersonalityType.allCases, id: \.rawValue) { personality in
                PersonalityCard(
                    personality: personality,
                    isSelected: personality == personalityEngine.currentPersonality,
                    isHovered: personality == hoveredPersonality
                )
                .onHover { isHovered in
                    hoveredPersonality = isHovered ? personality : nil
                    mcpService.emitPersonalityHover(
                        type: personality.rawValue,
                        hovered: isHovered
                    )
                }
                .onTapGesture {
                    selectPersonality(personality)
                    mcpService.emitPersonalitySelect(type: personality.rawValue)
                }
            }
        }
        .onChange(of: personalityEngine.currentPersonality) { newPersonality in
            transitionManager.updatePersonality(newPersonality)
        }
        .onChange(of: mcpService.personalityState) { newState in
            guard let newState = newState else { return }
            if let personality = PersonalityType(rawValue: newState.type) {
                if newState.active == true {
                    selectPersonality(personality)
                }
                if let isHovered = newState.hovered {
                    hoveredPersonality = isHovered ? personality : nil
                }
            }
        }
        .animation(.easeInOut, value: personalityEngine.currentPersonality)
        .onAppear {
            mcpService.connect()
        }
        .onDisappear {
            mcpService.disconnect()
        }
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

private struct PersonalityCard: View {
    let personality: PersonalityType
    let isSelected: Bool
    let isHovered: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            PersonalityIcon(personality: personality)
                .frame(width: 60, height: 60)
            
            // Title and Traits
            VStack(spacing: 8) {
                Text(personality.rawValue)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                HStack(spacing: 8) {
                    ForEach(personality.traits.prefix(3), id: \.self) { trait in
                        Text(trait)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
            }
            
            // Strength Indicator
            GeometryReader { geometry in
                Rectangle()
                    .fill(personalityColor)
                    .frame(width: geometry.size.width * personalityStrength)
                    .frame(height: 4)
                    .cornerRadius(2)
            }
            .frame(height: 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(personalityColor, lineWidth: isSelected ? 2 : 0)
                )
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
    }
    
    private var personalityColor: Color {
        switch personality {
        case .curator:
            return .purple
        case .enthusiast:
            return .orange
        case .explorer:
            return .blue
        case .social:
            return .green
        case .ambient:
            return .teal
        case .analyzer:
            return .red
        }
    }
    
    private var personalityStrength: CGFloat {
        switch personality {
        case .curator:
            return 0.8
        case .enthusiast:
            return 0.9
        case .explorer:
            return 0.7
        case .social:
            return 0.85
        case .ambient:
            return 0.75
        case .analyzer:
            return 0.95
        }
    }
}

private struct PersonalityIcon: View {
    let personality: PersonalityType
    
    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 30))
            .foregroundColor(iconColor)
    }
    
    private var iconName: String {
        switch personality {
        case .curator:
            return "star.circle.fill"
        case .enthusiast:
            return "heart.circle.fill"
        case .explorer:
            return "safari.fill"
        case .social:
            return "person.2.circle.fill"
        case .ambient:
            return "cloud.sun.fill"
        case .analyzer:
            return "chart.bar.xaxis"
        }
    }
    
    private var iconColor: Color {
        switch personality {
        case .curator:
            return .purple
        case .enthusiast:
            return .orange
        case .explorer:
            return .blue
        case .social:
            return .green
        case .ambient:
            return .teal
        case .analyzer:
            return .red
        }
    }
}
