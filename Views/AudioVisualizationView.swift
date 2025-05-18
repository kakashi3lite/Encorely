import SwiftUI
import AVFoundation

struct AudioVisualizationView: View {
    @ObservedObject var aiService: AIIntegrationService
    let audioProcessor: AudioProcessor
    
    // Audio state
    @State private var waveformData: [Float] = []
    @State private var spectrumData: [Float] = []
    @State private var currentFeatures: AudioFeatures?
    @State private var isAnalyzing = false
    
    // Error handling
    @State private var currentError: AppError?
    @State private var retryAction: (() -> Void)?
    
    // Visualization settings
    private let maxPoints = 100
    private let updateInterval: TimeInterval = 0.05
    private let barSpacing: CGFloat = 2
    
    var body: some View {
        VStack(spacing: 20) {
            // Error banner if needed
            if let error = currentError {
                ErrorBanner(error: error) {
                    retryAction?()
                }
            }
            
            // Waveform visualization
            VStack(alignment: .leading) {
                Text("Waveform")
                    .font(.headline)
                
                if isAnalyzing {
                    waveformView
                } else {
                    placeholderView
                }
            }
            
            // Frequency spectrum
            VStack(alignment: .leading) {
                Text("Frequency Spectrum")
                    .font(.headline)
                
                if isAnalyzing {
                    spectrumView
                } else {
                    placeholderView
                }
            }
            
            // Audio features
            if let features = currentFeatures {
                audioFeaturesView(features)
            }
        }
        .padding()
        .onAppear(perform: startAnalysis)
        .onDisappear(perform: stopAnalysis)
        .withErrorHandling()
    }
    
    // MARK: - Subviews
    
    private var waveformView: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midY = height / 2
                let pointSpacing = width / CGFloat(waveformData.count - 1)
                
                path.move(to: CGPoint(x: 0, y: midY))
                
                for (index, value) in waveformData.enumerated() {
                    let x = CGFloat(index) * pointSpacing
                    let y = midY + CGFloat(value) * midY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.blue, lineWidth: 2)
            .animation(.linear(duration: updateInterval), value: waveformData)
        }
        .frame(height: 100)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var spectrumView: some View {
        GeometryReader { geometry in
            HStack(spacing: barSpacing) {
                ForEach(Array(spectrumData.enumerated()), id: \.offset) { _, magnitude in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: (geometry.size.width - CGFloat(spectrumData.count) * barSpacing) / CGFloat(spectrumData.count))
                        .frame(height: geometry.size.height * CGFloat(magnitude))
                        .animation(.linear(duration: updateInterval), value: magnitude)
                }
            }
        }
        .frame(height: 100)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .frame(height: 100)
            .cornerRadius(8)
            .overlay(
                Text("No audio signal")
                    .foregroundColor(.secondary)
            )
    }
    
    private func audioFeaturesView(_ features: AudioFeatures) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audio Features")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                featureRow("Energy", value: features.energy)
                featureRow("Valence", value: features.valence)
                featureRow("Danceability", value: features.danceability)
                featureRow("Acousticness", value: features.acousticness)
                featureRow("Instrumentalness", value: features.instrumentalness)
                featureRow("Speechiness", value: features.speechiness)
                featureRow("Liveness", value: features.liveness)
                featureRow("Tempo", value: Float(features.tempo) / 200.0)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func featureRow(_ title: String, value: Float) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: geometry.size.width)
                     
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(value))
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
            
            Text(String(format: "%.2f", value))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Audio Analysis
    
    private func startAnalysis() {
        isAnalyzing = true
        
        do {
            try audioProcessor.startRealTimeAnalysis { features in
                updateVisualization(with: features)
            }
        } catch {
            handleAnalysisError(error)
        }
    }
    
    private func stopAnalysis() {
        isAnalyzing = false
        audioProcessor.stopRealTimeAnalysis()
    }
    
    private func updateVisualization(with features: AudioFeatures) {
        // Update waveform
        waveformData = generateWaveformData()
        
        // Update spectrum
        spectrumData = generateSpectrumData()
        
        // Update features
        currentFeatures = features
    }
    
    private func generateWaveformData() -> [Float] {
        // Simulated waveform data for demo
        var data: [Float] = []
        for _ in 0..<maxPoints {
            data.append(Float.random(in: -1...1))
        }
        return data
    }
    
    private func generateSpectrumData() -> [Float] {
        // Simulated spectrum data for demo
        var data: [Float] = []
        for _ in 0..<maxPoints/2 {
            data.append(Float.random(in: 0...1))
        }
        return data
    }
    
    private func handleAnalysisError(_ error: Error) {
        isAnalyzing = false
        currentError = error as? AppError ?? .audioProcessingFailed(error)
        retryAction = startAnalysis
    }
}