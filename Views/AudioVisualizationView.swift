//
//  AudioVisualizationView.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import SwiftUI
import AVKit

/// View for displaying audio visualizations and analysis insights
struct AudioVisualizationView: View {
    // Player
    let queuePlayer: AVQueuePlayer
    
    // AI service
    var aiService: AIIntegrationService
    
    // Current song info
    @ObservedObject var currentSongName: CurrentSongName
    
    // State
    @State private var audioFeatures: AudioFeatures?
    @State private var dominantMood: Mood = .neutral
    @State private var isAnalyzing: Bool = false
    @State private var visualizationData: [Float] = Array(repeating: 0.0, count: 8)
    @State private var animationAmount: CGFloat = 1.0
    
    // Feature names for radar chart
    private let featureNames = [
        "Energy", "Valence", "Danceability", "Acousticness",
        "Instrumental", "Speech", "Liveness", "Tempo"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                Text("Audio Analysis")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Current song info
                Text(currentSongName.name)
                    .font(.headline)
                    .lineLimit(1)
                
                // Mood badge
                if !isAnalyzing {
                    HStack {
                        Text("Detected Mood:")
                            .font(.subheadline)
                        
                        HStack(spacing: 4) {
                            Image(systemName: dominantMood.systemIcon)
                                .foregroundColor(dominantMood.color)
                            
                            Text(dominantMood.rawValue)
                                .font(.subheadline)
                                .foregroundColor(dominantMood.color)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(dominantMood.color.opacity(0.1))
                        )
                    }
                    .padding(.vertical, 8)
                }
                
                // Analyze button or progress indicator
                if isAnalyzing {
                    ProgressView("Analyzing audio...")
                        .padding()
                } else {
                    Button(action: {
                        analyzeCurrentAudio()
                    }) {
                        Label("Analyze Current Audio", systemImage: "waveform")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
                
                // Feature visualization
                if let features = audioFeatures {
                    VStack(spacing: 24) {
                        // Radar chart of features
                        ZStack {
                            RadarChartView(data: visualizationData, labels: featureNames)
                                .frame(height: 300)
                                .padding()
                                .scaleEffect(animationAmount)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        animationAmount = 1.0
                                    }
                                }
                            
                            // Highlight dominant mood
                            VStack {
                                Image(systemName: dominantMood.systemIcon)
                                    .font(.system(size: 40))
                                    .foregroundColor(dominantMood.color)
                                
                                Text(dominantMood.rawValue)
                                    .font(.headline)
                                    .foregroundColor(dominantMood.color)
                            }
                            .padding()
                            .background(Circle().fill(Color.white.opacity(0.8)))
                        }
                        
                        // Feature details
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Audio Features")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // BPM
                            FeatureDetailRow(
                                label: "Tempo",
                                value: String(format: "%.0f BPM", features.tempo),
                                icon: "metronome",
                                color: .orange
                            )
                            
                            // Energy
                            FeatureDetailRow(
                                label: "Energy",
                                value: String(format: "%.0f%%", features.energy * 100),
                                icon: "bolt.fill",
                                color: .red
                            )
                            
                            // Valence (happiness)
                            FeatureDetailRow(
                                label: "Positivity",
                                value: String(format: "%.0f%%", features.valence * 100),
                                icon: "sun.max.fill",
                                color: .yellow
                            )
                            
                            // Danceability
                            FeatureDetailRow(
                                label: "Danceability",
                                value: String(format: "%.0f%%", features.danceability * 100),
                                icon: "figure.wave",
                                color: .purple
                            )
                            
                            // Acousticness
                            FeatureDetailRow(
                                label: "Acoustic Elements",
                                value: String(format: "%.0f%%", features.acousticness * 100),
                                icon: "guitars",
                                color: .green
                            )
                            
                            // Instrumentalness
                            FeatureDetailRow(
                                label: "Instrumental Content",
                                value: String(format: "%.0f%%", features.instrumentalness * 100),
                                icon: "pianokeys",
                                color: .blue
                            )
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .padding(.horizontal)
                        
                        // Mood insights
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Mood Insights")
                                .font(.headline)
                            
                            Text(getMoodInsight(for: dominantMood))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .padding(.horizontal)
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
        .onAppear {
            // Initialize with defaults
            if let features = createDefaultFeatures() {
                audioFeatures = features
                visualizationData = aiService.generateVisualizationData(from: features)
                animationAmount = 0.5 // Start small for animation
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
            // Reset analysis when song ends
            audioFeatures = nil
        }
    }
    
    // Analyze current audio
    private func analyzeCurrentAudio() {
        guard queuePlayer.currentItem != nil else { return }
        
        isAnalyzing = true
        animationAmount = 0.5 // Reset for animation
        
        // Use audio analysis service to analyze current song
        aiService.detectMoodFromCurrentAudio(player: queuePlayer)
        
        // Simulate analysis with delay (in a real app, this would be actual analysis)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Generate random features for demonstration
            let features = createRandomFeatures()
            audioFeatures = features
            
            // Generate visualization data
            visualizationData = aiService.generateVisualizationData(from: features)
            
            // Detect mood
            dominantMood = aiService.audioAnalysisService.detectMood(from: features)
            
            // Animate chart
            withAnimation(.spring()) {
                animationAmount = 1.0
            }
            
            isAnalyzing = false
        }
    }
    
    // Create default features
    private func createDefaultFeatures() -> AudioFeatures? {
        return AudioFeatures(
            tempo: 120,
            energy: 0.5,
            valence: 0.5,
            danceability: 0.5,
            acousticness: 0.5,
            instrumentalness: 0.5,
            speechiness: 0.5,
            liveness: 0.5
        )
    }
    
    // Create random features for demonstration
    private func createRandomFeatures() -> AudioFeatures {
        return AudioFeatures(
            tempo: Float.random(in: 60...180),
            energy: Float.random(in: 0...1),
            valence: Float.random(in: 0...1),
            danceability: Float.random(in: 0...1),
            acousticness: Float.random(in: 0...1),
            instrumentalness: Float.random(in: 0...1),
            speechiness: Float.random(in: 0...1),
            liveness: Float.random(in: 0...1)
        )
    }
    
    // Get mood insight text
    private func getMoodInsight(for mood: Mood) -> String {
        switch mood {
        case .energetic:
            return "This song has high energy with an upbeat tempo and dynamic elements. It's great for workouts, parties, or starting your day with enthusiasm."
        case .relaxed:
            return "This track has a slower tempo with gentle progressions and calming elements. Perfect for unwinding, reducing stress, or creating a peaceful atmosphere."
        case .happy:
            return "The song uses major keys and bright tones with a positive vibe. It's ideal for lifting your spirits and celebrating good moments."
        case .melancholic:
            return "This piece has emotional depth with reflective elements. It provides space for processing feelings and contemplative moments."
        case .focused:
            return "The track maintains a balanced pattern with minimal distraction. It's designed to enhance concentration and productivity during work or study."
        case .romantic:
            return "This song expresses emotions through intimate arrangements. It's perfect for special moments or creating a warm atmosphere."
        case .angry:
            return "The music features powerful dynamics and intense expressions. It can help channel and process strong emotions."
        case .neutral:
            return "This track has a balanced sound that works in various contexts without strongly evoking specific emotions. It's versatile for everyday listening."
        }
    }
}

/// Radar chart for visualizing audio features
struct RadarChartView: View {
    let data: [Float]
    let labels: [String]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                ForEach(1...5, id: \.self) { level in
                    createPolygon(
                        sides: data.count,
                        size: CGFloat(level) / 5.0 * min(geometry.size.width, geometry.size.height) / 2,
                        center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    )
                    .stroke(Color.gray.opacity(0.3), lineWidth: level == 5 ? 2 : 1)
                }
                
                // Data polygon
                createDataPolygon(
                    data: data,
                    size: min(geometry.size.width, geometry.size.height) / 2,
                    center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                )
                .fill(Color.blue.opacity(0.3))
                
                createDataPolygon(
                    data: data,
                    size: min(geometry.size.width, geometry.size.height) / 2,
                    center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                )
                .stroke(Color.blue, lineWidth: 2)
                
                // Labels
                ForEach(0..<labels.count, id: \.self) { index in
                    let point = pointOnCircle(
                        center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2),
                        radius: min(geometry.size.width, geometry.size.height) / 2 + 20,
                        angle: 2 * .pi * CGFloat(index) / CGFloat(labels.count) - .pi / 2
                    )
                    
                    Text(labels[index])
                        .font(.caption)
                        .position(point)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // Create polygon for grid
    private func createPolygon(sides: Int, size: CGFloat, center: CGPoint) -> Path {
        var path = Path()
        let angle = 2 * .pi / CGFloat(sides)
        
        for side in 0..<sides {
            let x = center.x + size * cos(CGFloat(side) * angle - .pi / 2)
            let y = center.y + size * sin(CGFloat(side) * angle - .pi / 2)
            
            if side == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
    
    // Create polygon for data
    private func createDataPolygon(data: [Float], size: CGFloat, center: CGPoint) -> Path {
        var path = Path()
        let angle = 2 * .pi / CGFloat(data.count)
        
        for (index, value) in data.enumerated() {
            let scaledSize = CGFloat(value) * size
            let x = center.x + scaledSize * cos(CGFloat(index) * angle - .pi / 2)
            let y = center.y + scaledSize * sin(CGFloat(index) * angle - .pi / 2)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
    
    // Calculate point on circle for labels
    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        let x = center.x + radius * cos(angle)
        let y = center.y + radius * sin(angle)
        return CGPoint(x: x, y: y)
    }
}

/// Row displaying a feature detail
struct FeatureDetailRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            // Icon
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color))
            
            // Label
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            // Value
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
