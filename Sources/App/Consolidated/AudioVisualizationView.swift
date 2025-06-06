import SwiftUI
import AVFoundation
import Combine

struct AudioVisualizationView: View {
    // MARK: - Properties
    @ObservedObject var queuePlayer: AVQueuePlayer
    @ObservedObject var currentSongName: CurrentSongName
    @ObservedObject var mcpService = MCPSocketService()
    var aiService: AIIntegrationService
    
    @State private var visualizationData: [Float] = Array(repeating: 0, count: 40)
    @State private var currentMood: Mood = .neutral
    @State private var isAnalyzing = false
    @State private var showingMoodHistory = false
    @State private var showingFrequencyDetails = false
    @State private var selectedTimeRange: TimeRange = .lastHour
    @State private var visualizationStyle: VisualizationStyle = .modern
    @State private var sensitivity: Double = 1.0
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Current playback card
                    PlaybackCard(
                        songName: currentSongName.wrappedValue,
                        mood: currentMood,
                        isAnalyzing: isAnalyzing
                    )
                    .padding(.horizontal)
                    
                    // Visualization style picker
                    Picker("Style", selection: $visualizationStyle) {
                        ForEach(VisualizationStyle.allCases, id: \.self) { style in
                            Text(style.description).tag(style)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Visualization area
                    Group {
                        if visualizationStyle == .modern {
                            AnimatedVisualizationView(
                                audioData: visualizationData,
                                mood: currentMood,
                                sensitivity: sensitivity,
                                mcpService: mcpService
                            )
                            .frame(height: 300)
                            .cornerRadius(16)
                        } else {
                            ClassicVisualizationView(
                                audioData: visualizationData,
                                mood: currentMood,
                                sensitivity: sensitivity,
                                mcpService: mcpService
                            )
                            .frame(height: 300)
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 2)
                    )
                    .padding(.horizontal)
                    
                    // Sensitivity slider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visualization Sensitivity")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "speaker.wave.1")
                            Slider(value: $sensitivity, in: 0.1...2.0)
                            Image(systemName: "speaker.wave.3")
                        }
                    }
                    .padding(.horizontal)
                    
                    // Audio characteristics
                    AudioCharacteristicsGrid(
                        characteristics: getCurrentAudioCharacteristics()
                    )
                    .padding(.horizontal)
                    
                    // Analysis controls
                    VStack(spacing: 16) {
                        // Time range picker
                        Picker("Time Range", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.description).tag(range)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        // Action buttons
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                AnalysisButton(
                                    title: "Mood History",
                                    icon: "chart.line.uptrend.xyaxis",
                                    action: { showingMoodHistory = true }
                                )
                                
                                AnalysisButton(
                                    title: "Frequency Analysis",
                                    icon: "waveform.path.ecg",
                                    action: { showingFrequencyDetails = true }
                                )
                                
                                AnalysisButton(
                                    title: "Generate Report",
                                    icon: "doc.text.viewfinder",
                                    action: generateAnalysisReport
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Audio Analysis")
            .sheet(isPresented: $showingMoodHistory) {
                MoodHistoryView(aiService: aiService)
            }
            .sheet(isPresented: $showingFrequencyDetails) {
                FrequencyAnalysisView(visualizationData: visualizationData)
            }
            .onAppear {
                mcpService.connect()
                startVisualization()
            }
            .onDisappear {
                mcpService.disconnect()
                stopVisualization()
            }
        }
    }
    
    // MARK: - Supporting Views
    
    struct PlaybackCard: View {
        let songName: String
        let mood: Mood
        let isAnalyzing: Bool
        
        var body: some View {
            VStack(spacing: 12) {
                // Song info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Now Playing")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(songName == "Not Playing" ? "No song playing" : songName)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    // Mood indicator
                    if songName != "Not Playing" {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Current Mood")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: mood.systemIcon)
                                Text(mood.rawValue)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(mood.color)
                        }
                    }
                }
                
                if isAnalyzing {
                    // Analysis progress
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                        Text("Analyzing audio characteristics...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5)
        }
    }
    
    struct AudioCharacteristicsGrid: View {
        let characteristics: [AudioCharacteristic]
        
        var body: some View {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(characteristics) { characteristic in
                    CharacteristicCard(
                        title: characteristic.name,
                        value: characteristic.value,
                        icon: characteristic.icon,
                        color: characteristic.color
                    )
                }
            }
        }
    }
    
    struct CharacteristicCard: View {
        let title: String
        let value: String
        let icon: String
        let color: Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: color.opacity(0.1), radius: 5)
        }
    }
    
    struct AnalysisButton: View {
        let title: String
        let icon: String
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                    Text(title)
                        .font(.caption)
                }
                .frame(minWidth: 100)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func startVisualization() {
        // Start audio analysis timer
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard let audioFeatures = analyzeAudio() else { return }
            
            // Update visualization data
            visualizationData = audioFeatures.frequencies.map { Float($0) }
            
            // Send audio features to MCP server
            mcpService.emitAudioVisualization(audioFeatures)
        }
    }
    
    private func stopVisualization() {
        // Clean up timers and audio analysis
    }
    
    private func analyzeAudio() -> AudioFeatures? {
        guard let currentItem = queuePlayer.currentItem else { return nil }
        
        let energy = calculateEnergy(currentItem)
        let tempo = calculateTempo(currentItem)
        let valence = calculateValence(currentItem)
        let frequencies = calculateFrequencies(currentItem)
        
        return AudioFeatures(
            energy: energy,
            tempo: tempo,
            valence: valence,
            frequencies: frequencies
        )
    }
    
    private func getCurrentAudioCharacteristics() -> [AudioCharacteristic] {
        return [
            AudioCharacteristic(
                name: "Tempo",
                value: "128 BPM",
                icon: "metronome",
                color: .blue
            ),
            AudioCharacteristic(
                name: "Key",
                value: "C Major",
                icon: "music.quarternote.3",
                color: .green
            ),
            AudioCharacteristic(
                name: "Energy",
                value: "High",
                icon: "bolt.fill",
                color: .orange
            ),
            AudioCharacteristic(
                name: "Dynamics",
                value: "12 dB",
                icon: "waveform",
                color: .purple
            )
        ]
    }
    
    private func generateAnalysisReport() {
        // Generate and share analysis report
    }
}

// MARK: - Supporting Types

struct AudioCharacteristic: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let icon: String
    let color: Color
}

enum TimeRange: String, CaseIterable {
    case lastHour = "1H"
    case lastDay = "24H"
    case lastWeek = "1W"
    case lastMonth = "1M"
    
    var description: String {
        switch self {
        case .lastHour: return "1 Hour"
        case .lastDay: return "24 Hours"
        case .lastWeek: return "1 Week"
        case .lastMonth: return "1 Month"
        }
    }
}

// MARK: - Visualization Style
enum VisualizationStyle: String, CaseIterable {
    case classic
    case modern
    
    var description: String {
        switch self {
        case .classic: return "Classic"
        case .modern: return "Modern"
        }
    }
}

// MARK: - Preview

struct AudioVisualizationView_Previews: PreviewProvider {
    static var previews: some View {
        AudioVisualizationView(
            queuePlayer: AVQueuePlayer(),
            currentSongName: CurrentSongName(),
            aiService: AIIntegrationService()
        )
    }
}

private struct AnimatedVisualizationView: View {
    let audioData: [Float]
    let mood: Mood
    let sensitivity: Double
    let mcpService: MCPSocketService
    
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: geometry.size.width / CGFloat(audioData.count * 2)) {
                ForEach(Array(audioData.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    mood.color.opacity(0.6),
                                    mood.color
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: geometry.size.width / CGFloat(audioData.count) / 1.5,
                               height: geometry.size.height * CGFloat(value) * CGFloat(sensitivity))
                        .animation(
                            Animation.spring(response: 0.3, dampingFraction: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.05),
                            value: isAnimating
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground).opacity(0.1))
            .onAppear {
                isAnimating = true
            }
        }
    }
}

private struct ClassicVisualizationView: View {
    let audioData: [Float]
    let mood: Mood
    let sensitivity: Double
    let mcpService: MCPSocketService
    
    var body: some View {
        GeometryReader { geometry in
            let maxHeight = geometry.size.height
            let width = geometry.size.width
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: maxHeight / 2))
                
                for (index, value) in audioData.enumerated() {
                    let x = width * CGFloat(index) / CGFloat(audioData.count)
                    let y = maxHeight / 2 + CGFloat(value) * maxHeight / 2 * CGFloat(sensitivity)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                // Mirror the waveform
                for (index, value) in audioData.enumerated().reversed() {
                    let x = width * CGFloat(index) / CGFloat(audioData.count)
                    let y = maxHeight / 2 - CGFloat(value) * maxHeight / 2 * CGFloat(sensitivity)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        mood.color.opacity(0.3),
                        mood.color.opacity(0.7)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: maxHeight / 2))
                    
                    for (index, value) in audioData.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(audioData.count)
                        let y = maxHeight / 2 + CGFloat(value) * maxHeight / 2 * CGFloat(sensitivity)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(mood.color, lineWidth: 2)
                .blur(radius: 1)
            )
        }
    }
}
