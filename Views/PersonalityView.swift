//
//  PersonalityView.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import SwiftUI

/// View for personality type selection and profile management
struct PersonalityView: View {
    @ObservedObject var personalityEngine: PersonalityEngine
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedPersonality: PersonalityType
    
    init(personalityEngine: PersonalityEngine) {
        self.personalityEngine = personalityEngine
        self._selectedPersonality = State(initialValue: personalityEngine.currentPersonality)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current personality profile
                    VStack {
                        Text("Your Music Personality")
                            .font(.headline)
                            .padding(.top)
                        
                        ZStack {
                            Circle()
                                .fill(personalityEngine.currentPersonality.themeColor.opacity(0.2))
                                .frame(width: 120, height: 120)
                            
                            VStack {
                                Image(systemName: getPersonalityIcon(personalityEngine.currentPersonality))
                                    .font(.system(size: 40))
                                    .foregroundColor(personalityEngine.currentPersonality.themeColor)
                                
                                Text(personalityEngine.currentPersonality.rawValue)
                                    .font(.headline)
                                    .foregroundColor(personalityEngine.currentPersonality.themeColor)
                                    .padding(.top, 4)
                            }
                        }
                        
                        Text(getPersonalityTagline(personalityEngine.currentPersonality))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                    .padding(.bottom)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    
                    // Personality traits chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Personality Traits")
                            .font(.headline)
                            .padding(.leading)
                        
                        VStack(spacing: 12) {
                            ForEach(personalityEngine.getPersonalityTraits(), id: \.type) { trait in
                                PersonalityTraitBar(
                                    type: trait.type,
                                    value: trait.value
                                )
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                        .shadow(radius: 2)
                        .padding(.horizontal)
                    }
                    
                    // Personality type selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose Your Personality Type")
                            .font(.headline)
                            .padding(.leading)
                        
                        ForEach(PersonalityType.allCases, id: \.self) { personality in
                            PersonalitySelectionButton(
                                type: personality,
                                isSelected: selectedPersonality == personality,
                                action: {
                                    selectedPersonality = personality
                                }
                            )
                        }
                        
                        // Apply button
                        Button(action: {
                            personalityEngine.setPersonalityType(selectedPersonality)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Apply Personality Type")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedPersonality.themeColor)
                                .cornerRadius(10)
                        }
                        .disabled(selectedPersonality == personalityEngine.currentPersonality)
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    
                    // How it works section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How It Works")
                            .font(.headline)
                        
                        Text("Your music personality type determines how the app's interface and features are tailored to your preferences. The app learns from your listening habits and interactions to continually refine your profile, but you can always manually select your preferred type.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                    .shadow(radius: 2)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationBarTitle("Personality Profile", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func getPersonalityIcon(_ type: PersonalityType) -> String {
        switch type {
        case .explorer: return "safari"
        case .curator: return "folder"
        case .enthusiast: return "star"
        case .social: return "person.2"
        case .ambient: return "waveform"
        case .analyzer: return "chart.bar"
        }
    }
    
    private func getPersonalityTagline(_ type: PersonalityType) -> String {
        switch type {
        case .explorer:
            return "You thrive on discovering new music and fresh experiences"
        case .curator:
            return "You enjoy organizing and perfecting your music collections"
        case .enthusiast:
            return "You appreciate deep dives into artists and genres you love"
        case .social:
            return "You value music as a way to connect with others"
        case .ambient:
            return "You enjoy music as a backdrop to your daily activities"
        case .analyzer:
            return "You appreciate the technical aspects and details of music"
        }
    }
}

/// Bar representing a personality trait value
struct PersonalityTraitBar: View {
    let type: PersonalityType
    let value: Float
    
    var body: some View {
        HStack {
            Text(type.rawValue)
                .font(.subheadline)
                .frame(width: 100, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                        .cornerRadius(6)
                    
                    Rectangle()
                        .fill(type.themeColor)
                        .frame(width: CGFloat(value) * geometry.size.width, height: 12)
                        .cornerRadius(6)
                }
            }
            .frame(height: 12)
        }
    }
}

/// Button for selecting a personality type
struct PersonalitySelectionButton: View {
    let type: PersonalityType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(isSelected ? type.themeColor : Color.gray.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: isSelected ? "checkmark" : "")
                            .foregroundColor(.white)
                            .font(.system(size: 12, weight: .bold))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? type.themeColor : .primary)
                    
                    Text(getPersonalityDescription(type))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? type.themeColor : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private func getPersonalityDescription(_ type: PersonalityType) -> String {
        switch type {
        case .explorer:
            return "You value discovery and variety. The app will focus on helping you find new music."
        case .curator:
            return "You value organization and quality. The app will focus on helping you manage collections."
        case .enthusiast:
            return "You value deep dives into artists and genres. The app will provide extensive details."
        case .social:
            return "You value sharing and connecting. The app will highlight social features."
        case .ambient:
            return "You value background listening. The app will focus on seamless playback experiences."
        case .analyzer:
            return "You value technical details. The app will provide in-depth audio information."
        }
    }
}
