//
//  MoodView.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import SwiftUI

/// View for selecting and displaying the current mood
struct MoodView: View {
    @ObservedObject var moodEngine: MoodEngine
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedMood: Mood = .neutral
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Current mood indicator
                VStack {
                    Text("Your Current Mood")
                        .font(.headline)
                        .padding(.top)
                    
                    ZStack {
                        Circle()
                            .fill(moodEngine.currentMood.color.opacity(0.2))
                            .frame(width: 120, height: 120)
                        
                        VStack {
                            Image(systemName: moodEngine.currentMood.systemIcon)
                                .font(.system(size: 40))
                                .foregroundColor(moodEngine.currentMood.color)
                            
                            Text(moodEngine.currentMood.rawValue)
                                .font(.headline)
                                .foregroundColor(moodEngine.currentMood.color)
                                .padding(.top, 4)
                        }
                    }
                    
                    // Confidence indicator
                    HStack {
                        Text("Confidence:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .fill(moodEngine.currentMood.color)
                                    .frame(width: CGFloat(moodEngine.moodConfidence) * geometry.size.width, height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                        .padding(.leading, 8)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                .shadow(radius: 2)
                .padding(.horizontal)
                
                // Mood selection grid
                Text("Select a Different Mood")
                    .font(.headline)
                    .padding(.top)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        MoodSelectionButton(
                            mood: mood,
                            isSelected: selectedMood == mood,
                            action: {
                                selectedMood = mood
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                // Apply button
                Button(action: {
                    moodEngine.setMood(selectedMood, confidence: 0.9)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Apply Mood")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedMood.color)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .disabled(selectedMood == moodEngine.currentMood)
                .padding(.top)
                
                // Mood explanation
                VStack(alignment: .leading, spacing: 12) {
                    Text("About \(selectedMood.rawValue) Music")
                        .font(.headline)
                    
                    Text(getMoodDescription(selectedMood))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                .shadow(radius: 2)
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
            }
            .padding(.vertical)
            .navigationBarTitle("Your Mood", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                selectedMood = moodEngine.currentMood
            }
        }
    }
    
    private func getMoodDescription(_ mood: Mood) -> String {
        switch mood {
        case .energetic:
            return "Energetic music features high tempos, strong beats, and dynamic elements that can boost your energy levels and motivation. Perfect for workouts, parties, or starting your day with enthusiasm."
        case .relaxed:
            return "Relaxed music has slower tempos, gentle transitions, and soothing sounds that help reduce stress and promote calm. Ideal for unwinding after a busy day or creating a peaceful atmosphere."
        case .happy:
            return "Happy music often uses major keys, upbeat rhythms, and bright tones to evoke feelings of joy and optimism. Great for lifting your spirits or celebrating positive moments."
        case .melancholic:
            return "Melancholic music embraces emotional depth through minor keys and expressive melodies. It can help process feelings, inspire reflection, or provide comfort during contemplative moments."
        case .focused:
            return "Focused music balances stimulation and calm with consistent patterns and minimal distractions. Designed to enhance concentration and productivity during work or study sessions."
        case .romantic:
            return "Romantic music expresses feelings of love and connection through emotional melodies and intimate arrangements. Perfect for special moments, date nights, or setting a warm atmosphere."
        case .angry:
            return "Intense music characterized by powerful dynamics, complex patterns, and cathartic expression. Can help channel and process strong emotions or fuel high-intensity physical activities."
        case .neutral:
            return "Balanced music that works in various contexts without strongly evoking specific emotions. Versatile for everyday listening when you want a pleasant soundtrack without mood manipulation."
        }
    }
}

/// Button for selecting a mood
struct MoodSelectionButton: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? mood.color : mood.color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: mood.systemIcon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : mood.color)
                }
                
                Text(mood.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? mood.color : .primary)
            }
        }
    }
}
