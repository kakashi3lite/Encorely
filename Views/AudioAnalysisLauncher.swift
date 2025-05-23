import SwiftUI

/// Launcher for the enhanced audio analysis features
struct AudioAnalysisLauncher: View {
    @StateObject private var analysisService = AudioAnalysisService()
    @State private var showAnalysis = false
    
    var body: some View {
        Button(action: {
            showAnalysis = true
        }) {
            VStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
                Text("Enhanced Audio Analysis")
                    .font(.headline)
                Text("Analyze audio with advanced features")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showAnalysis) {
            NavigationView {
                AudioAnalysisView(analysisService: analysisService)
                    .navigationTitle("Audio Analysis")
                    .navigationBarItems(trailing: Button("Done") {
                        showAnalysis = false
                    })
            }
        }
    }
}

/// Integration widget for adding to dashboard screens
struct AudioAnalysisDashboardWidget: View {
    @StateObject private var analysisService = AudioAnalysisService()
    @State private var showAnalysis = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Audio Analysis")
                    .font(.headline)
                Spacer()
                Button(action: {
                    showAnalysis = true
                }) {
                    Text("Open")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.blue))
                        .foregroundColor(.white)
                }
            }
            
            if let features = analysisService.currentFeatures {
                // Show a preview of recent analysis
                HStack(spacing: 20) {
                    VStack {
                        Text("Energy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f", features.energy ?? 0))
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    
                    VStack {
                        Text("Tempo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(features.tempo ?? 0))")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    
                    VStack {
                        Text("Mood")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(determineMood(features: features))
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                }
                .padding(.vertical, 8)
            } else {
                Text("Tap to analyze audio and discover features")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 16)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .sheet(isPresented: $showAnalysis) {
            NavigationView {
                AudioAnalysisView(analysisService: analysisService)
                    .navigationTitle("Audio Analysis")
                    .navigationBarItems(trailing: Button("Done") {
                        showAnalysis = false
                    })
            }
        }
    }
    
    // Simple mood determination based on audio features
    private func determineMood(features: AudioFeatures) -> String {
        if features.energy ?? 0 > 0.7 {
            return features.valence ?? 0 > 0.7 ? "Happy" : "Energetic"
        } else {
            return features.valence ?? 0 > 0.7 ? "Relaxed" : "Melancholic"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AudioAnalysisLauncher()
        AudioAnalysisDashboardWidget()
    }
    .padding()
}
