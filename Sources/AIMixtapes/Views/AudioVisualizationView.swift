import SwiftUI
import AVFoundation
import Combine
import Domain

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
    @State private var visualizationStyle: VisualizationStyle = .classic
    @State private var sensitivity: Double = 1.0
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Playback info card
                    PlaybackCard(
                        songName: currentSongName ?? "Not Playing",
                        mood: aiService.moodEngine.currentMood,
                        isAnalyzing: isAnalyzing
                    )
                    .padding(.horizontal)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Now playing: \(currentSongName ?? "No song playing")")
                    .accessibilityAddTraits(.updatesFrequently)
                    
                    // Visualization style picker
                    Picker("Style", selection: $visualizationStyle) {
                        ForEach(VisualizationStyle.allCases, id: \.self) { style in
                            Text(style.description).tag(style)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .accessibilityLabel("Visualization style")
                    .accessibilityHint("Select how the audio visualization is displayed")
                    
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
                            .accessibilityLabel("Audio visualization")
                            .accessibilityValue("Modern style visualization")
                            .accessibilityAddTraits(.updatesFrequently)
                        } else {
                            VisualizationView(data: visualizationData)
                                .frame(height: 200)
                                .accessibilityLabel("Audio visualization")
                                .accessibilityValue("Classic style visualization")
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Sensitivity control
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visualization Sensitivity")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                        
                        HStack {
                            Image(systemName: "speaker.wave.1")
                                .accessibilityHidden(true)
                            Slider(value: $sensitivity, in: 0.1...2.0)
                                .accessibilityLabel("Visualization sensitivity")
                                .accessibilityValue("\(Int(sensitivity * 100))%")
                                .accessibilityHint("Adjust how sensitive the visualization is to audio changes")
                            Image(systemName: "speaker.wave.3")
                                .accessibilityHidden(true)
                        }
                    }
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
                        .accessibilityLabel("Analysis time range")
                        .accessibilityHint("Select the time period for audio analysis")
                        
                        // Action buttons
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                AnalysisButton(
                                    title: "Mood History",
                                    icon: "chart.line.uptrend.xyaxis",
                                    action: { showingMoodHistory = true }
                                )
                                .accessibilityLabel("View mood history")
                                .accessibilityHint("Shows how your music mood has changed over time")
                                
                                AnalysisButton(
                                    title: "Frequency Analysis",
                                    icon: "waveform.path.ecg",
                                    action: { showingFrequencyDetails = true }
                                )
                                .accessibilityLabel("View frequency analysis")
                                .accessibilityHint("Shows detailed frequency breakdown of your music")
                                
                                AnalysisButton(
                                    title: "Generate Report",
                                    icon: "doc.text.viewfinder",
                                    action: generateAnalysisReport
                                )
                                .accessibilityLabel("Generate analysis report")
                                .accessibilityHint("Creates a detailed report of your music analysis")
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
                            .accessibilityHidden(true)
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
                                .accessibilityHidden(true)
                            HStack(spacing: 4) {
                                Image(systemName: mood.systemIcon)
                                    .accessibilityHidden(true)
                                Text(mood.rawValue)
                                    .fontWeight(.medium)
                                    .foregroundColor(mood.color)
                            }
                        }
                    }
                }
                
                if isAnalyzing {
                    // Analysis progress
                    HStack(spacing: 8) {
                        ProgressView()
                            .accessibilityLabel("Analysis in progress")
                        Text("Analyzing audio...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(songName == "Not Playing" ? "No song playing" : "Now playing: \(songName)")")
            .accessibilityValue(songName != "Not Playing" ? "Current mood: \(mood.rawValue)" : "")
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
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(characteristic.name)")
                    .accessibilityValue(characteristic.value)
                    .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Audio characteristics")
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
                        .accessibilityHidden(true)
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
            .shadow(radius: 2)
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

enum VisualizationStyle: String, CaseIterable {
    case classic = "Classic"
    case modern = "Modern"
    
    var description: String {
        rawValue
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
