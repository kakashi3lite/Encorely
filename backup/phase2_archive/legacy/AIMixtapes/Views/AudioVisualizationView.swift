import AVKit
import SwiftUI

struct AudioVisualizationView: View {
    let queuePlayer: AVQueuePlayer
    let aiService: AIIntegrationService
    @ObservedObject var currentSongName: CurrentSongName

    @State private var selectedTimeRange: TimeRange = .thirtySeconds
    @State private var showingMoodHistory = false
    @State private var showingFrequencyDetails = false
    @State private var showingReport = false
    @State private var visualizationData: AudioVisualizationData?
    @State private var isAnalyzing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current playback card
                PlaybackCard(
                    songName: currentSongName.wrappedValue,
                    mood: aiService.moodEngine.currentMood,
                    isAnalyzing: isAnalyzing
                )
                .padding(.horizontal)

                // Visualization view
                ZStack {
                    if let data = visualizationData {
                        AnimatedVisualizationView(
                            audioData: data.waveformData,
                            mood: aiService.moodEngine.currentMood,
                            sensitivity: aiService.moodEngine.moodIntensity
                        )
                    } else {
                        ProgressView("Analyzing audio...")
                    }
                }
                .frame(height: 200)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 2)
                .padding(.horizontal)

                // Analysis metrics
                VStack(spacing: 16) {
                    HStack {
                        MetricCard(
                            title: "Tempo",
                            value: "\(Int(visualizationData?.tempo ?? 0)) BPM",
                            icon: "metronome",
                            color: .blue
                        )

                        MetricCard(
                            title: "Key",
                            value: visualizationData?.key ?? "N/A",
                            icon: "music.note",
                            color: .purple
                        )

                        MetricCard(
                            title: "Energy",
                            value: "\(Int((visualizationData?.energy ?? 0) * 100))%",
                            icon: "bolt.fill",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                }

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
        .navigationTitle("Audio Analysis")
        .background(Color(.systemGroupedBackground))
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

    // MARK: - Helper Functions

    private func startVisualization() {
        isAnalyzing = true
        // Start audio analysis and update visualizationData
        // This would be implemented based on your audio analysis service
    }

    private func stopVisualization() {
        isAnalyzing = false
        visualizationData = nil
    }

    private func generateAnalysisReport() {
        showingReport = true
        // Generate and show analysis report
    }
}

// MARK: - Supporting Views

struct PlaybackCard: View {
    let songName: String
    let mood: Mood
    let isAnalyzing: Bool

    var body: some View {
        VStack(spacing: 12) {
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
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
}

struct MetricCard: View {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
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
                    .font(.callout)
            }
            .frame(width: 120)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }
}
