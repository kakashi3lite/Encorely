import SwiftUI
import AVFoundation
import Combine

struct AudioVisualizationView: View {
    // MARK: - Properties
    @ObservedObject var queuePlayer: AVQueuePlayer
    @ObservedObject var currentSongName: CurrentSongName
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
                                sensitivity: sensitivity
                            )
                            .frame(height: 300)
                            .cornerRadius(16)
                            .shadow(radius: 2)
                        } else {
                            VisualizationView(data: visualizationData)
                                .frame(height: 200)
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
                startVisualization()
            }
            .onDisappear {
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
    
    struct VisualizationView: View {
        let data: [Float]
        @State private var animate = false
        
        var body: some View {
            HStack(spacing: 2) {
                ForEach(data.indices, id: \.self) { index in
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 4)
                        .frame(height: CGFloat(data[index] * 100))
                        .animation(
                            Animation.easeInOut(duration: 0.2)
                                .delay(Double(index) * 0.02)
                        )
                }
            }
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
        // Start audio monitoring and update visualization
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            updateVisualization()
        }
        
        // Start mood analysis if song is playing
        if currentSongName.wrappedValue != "Not Playing" {
            analyzeCurrentAudio()
        }
    }
    
    private func stopVisualization() {
        // Clean up timers and audio analysis
    }
    
    private func updateVisualization() {
        guard currentSongName.wrappedValue != "Not Playing" else {
            visualizationData = Array(repeating: 0, count: 40)
            return
        }
        
        // Simulate audio visualization data
        visualizationData = (0..<40).map { _ in
            Float.random(in: 0.1...1.0)
        }
    }
    
    private func analyzeCurrentAudio() {
        isAnalyzing = true
        
        // Simulate audio analysis
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            currentMood = Mood.allCases.randomElement() ?? .neutral
            isAnalyzing = false
        }
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
