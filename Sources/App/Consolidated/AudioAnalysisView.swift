import SwiftUI

/// View that displays audio analysis results with visualizations
struct AudioAnalysisView: View {
    @ObservedObject var analysisService: AudioAnalysisService
    @State private var selectedFile: URL?
    @State private var isAnalyzing = false
    @State private var showFilePicker = false
    @State private var analysisError: Error?
    @State private var showError = false

    // Animation properties
    @State private var animateSpectrogram = false
    @State private var animateProgress = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Audio Analysis")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Progress indicator
            if isAnalyzing {
                ProgressView(value: analysisService.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(animateProgress ? 1.05 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                        value: animateProgress
                    )
                    .onAppear {
                        animateProgress = true
                    }

                Text("Analyzing audio...")
                    .foregroundColor(.secondary)
            }

            // Analysis results
            if let features = analysisService.currentFeatures {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Energy & Mood section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Energy & Mood")
                                .font(.headline)

                            // Energy meter
                            HStack {
                                Text("Energy")
                                    .frame(width: 100, alignment: .leading)

                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .frame(width: geometry.size.width, height: 8)
                                            .opacity(0.3)
                                            .foregroundColor(.gray)

                                        Rectangle()
                                            .frame(
                                                width: geometry.size.width * CGFloat(features.energy ?? 0),
                                                height: 8
                                            )
                                            .foregroundColor(.orange)
                                    }
                                    .cornerRadius(4)
                                }
                                .frame(height: 8)

                                Text(String(format: "%.2f", features.energy ?? 0))
                                    .frame(width: 50, alignment: .trailing)
                                    .foregroundColor(.secondary)
                            }

                            // Valence meter
                            HStack {
                                Text("Valence")
                                    .frame(width: 100, alignment: .leading)

                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .frame(width: geometry.size.width, height: 8)
                                            .opacity(0.3)
                                            .foregroundColor(.gray)

                                        Rectangle()
                                            .frame(
                                                width: geometry.size.width * CGFloat(features.valence ?? 0),
                                                height: 8
                                            )
                                            .foregroundColor(.blue)
                                    }
                                    .cornerRadius(4)
                                }
                                .frame(height: 8)

                                Text(String(format: "%.2f", features.valence ?? 0))
                                    .frame(width: 50, alignment: .trailing)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)

                        // Tempo & Rhythm section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tempo & Rhythm")
                                .font(.headline)

                            if let tempo = features.tempo {
                                HStack {
                                    Image(systemName: "metronome")
                                    Text("\(Int(tempo)) BPM")
                                    Spacer()

                                    // Tempo classification
                                    Text(classifyTempo(tempo))
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Danceability
                            HStack {
                                Text("Danceability")
                                    .frame(width: 100, alignment: .leading)

                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .frame(width: geometry.size.width, height: 8)
                                            .opacity(0.3)
                                            .foregroundColor(.gray)

                                        Rectangle()
                                            .frame(
                                                width: geometry.size.width * CGFloat(features.danceability ?? 0),
                                                height: 8
                                            )
                                            .foregroundColor(.purple)
                                    }
                                    .cornerRadius(4)
                                }
                                .frame(height: 8)

                                Text(String(format: "%.2f", features.danceability ?? 0))
                                    .frame(width: 50, alignment: .trailing)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)

                        // Spectral Features
                        if let spectral = features.spectralFeatures {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Spectral Analysis")
                                    .font(.headline)

                                // Visualize frequency bands
                                HStack(alignment: .bottom, spacing: 2) {
                                    ForEach(0 ..< 10, id: \.self) { index in
                                        let height = getRandomizedBandHeight(index: index, spectral: spectral)
                                        Rectangle()
                                            .fill(bandColor(index: index))
                                            .frame(height: height)
                                            .animation(.easeInOut(duration: 0.5), value: animateSpectrogram)
                                    }
                                }
                                .frame(height: 100)
                                .padding(.vertical, 8)
                                .onAppear {
                                    animateSpectrogram = true
                                }

                                // Key spectral metrics
                                VStack(alignment: .leading, spacing: 4) {
                                    KeyValueRow(key: "Bass Energy", value: spectral.bassEnergy)
                                    KeyValueRow(key: "Mid Energy", value: spectral.midEnergy)
                                    KeyValueRow(key: "Treble", value: spectral.trebleEnergy)
                                    KeyValueRow(key: "Brightness", value: spectral.brightness)
                                    KeyValueRow(key: "Spectral Flatness", value: spectral.flatness)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }

                        // Performance metrics
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Performance")
                                .font(.headline)

                            Text(analysisService.performanceReport)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding()
                }
            } else {
                // No analysis yet
                VStack(spacing: 20) {
                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("No audio analyzed yet")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text("Select an audio file to begin analysis")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding()
            }

            Spacer()

            // Action buttons
            HStack {
                Button(action: {
                    showFilePicker = true
                }) {
                    Label("Select Audio", systemImage: "music.note")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .padding(.horizontal)

                if isAnalyzing {
                    Button(action: {
                        analysisService.cancelCurrentAnalysis()
                        isAnalyzing = false
                    }) {
                        Label("Cancel", systemImage: "stop.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .padding()
        .sheet(isPresented: $showFilePicker) {
            // File picker would go here
            Text("This would be a file picker in a real app")
                .padding()
        }
        .alert("Analysis Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = analysisError {
                Text(error.localizedDescription)
            }
        }
    }

    // Helper methods
    private func classifyTempo(_ tempo: Float) -> String {
        switch tempo {
        case ..<70:
            "Slow"
        case 70 ..< 110:
            "Moderate"
        case 110 ..< 140:
            "Upbeat"
        default:
            "Fast"
        }
    }

    private func getRandomizedBandHeight(index: Int, spectral: SpectralFeatures) -> CGFloat {
        var baseHeight: CGFloat = 20

        // Use real spectral data for the visualization
        switch index {
        case 0, 1, 2:
            baseHeight = CGFloat(spectral.bassEnergy * 100)
        case 3, 4, 5, 6:
            baseHeight = CGFloat(spectral.midEnergy * 100)
        default:
            baseHeight = CGFloat(spectral.trebleEnergy * 100)
        }

        // Add some subtle randomization for visual effect
        let randomFactor = 1.0 + CGFloat.random(in: -0.1 ... 0.1)
        return max(4, baseHeight * randomFactor)
    }

    private func bandColor(index: Int) -> Color {
        let hue = Double(index) / 10.0
        return Color(hue: hue, saturation: 0.8, brightness: 0.9)
    }
}

// Helper view for key-value display
struct KeyValueRow: View {
    var key: String
    var value: Float

    var body: some View {
        HStack {
            Text(key)
                .frame(width: 130, alignment: .leading)
                .foregroundColor(.secondary)

            Text(String(format: "%.2f", value))
                .fontWeight(.medium)

            Spacer()
        }
    }
}

#Preview {
    AudioAnalysisView(analysisService: AudioAnalysisService())
}
