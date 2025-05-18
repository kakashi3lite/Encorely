import SwiftUI
import AVFoundation
import Combine

struct AudioVisualizationView: View {
    // MARK: - Properties
    
    @ObservedObject var moodEngine: MoodEngine
    @StateObject private var viewModel: AudioVisualizationViewModel
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 50)
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    // MARK: - Initialization
    
    init(moodEngine: MoodEngine) {
        self.moodEngine = moodEngine
        _viewModel = StateObject(wrappedValue: AudioVisualizationViewModel(moodEngine: moodEngine))
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient based on mood
                LinearGradient(
                    gradient: moodEngine.currentMood.gradient,
                    startPoint: .bottom,
                    endPoint: .top
                )
                .opacity(0.3)
                
                // Spectrum visualization
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(viewModel.spectrum.enumerated()), id: \.offset) { index, magnitude in
                        SpectrumBar(
                            magnitude: magnitude,
                            mood: moodEngine.currentMood,
                            maxHeight: geometry.size.height * 0.8
                        )
                        .animation(.easeOut(duration: 0.1), value: magnitude)
                    }
                }
                
                // Mood indicators
                if let moodIndicators = viewModel.currentMoodIndicators {
                    MoodVisualizationOverlay(
                        indicators: moodIndicators,
                        mood: moodEngine.currentMood,
                        size: geometry.size
                    )
                }
            }
            .onReceive(timer) { _ in
                viewModel.updateVisualization()
            }
        }
    }
}

// MARK: - Supporting Views

struct SpectrumBar: View {
    let magnitude: Float
    let mood: Mood
    let maxHeight: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(mood.color)
            .frame(height: CGFloat(magnitude) * maxHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(mood.color.opacity(0.5), lineWidth: 0.5)
            )
    }
}

struct MoodVisualizationOverlay: View {
    let indicators: MoodIndicators
    let mood: Mood
    let size: CGSize
    
    var body: some View {
        Canvas { context, size in
            // Draw circular visualization
            let center = CGPoint(x: size.width/2, y: size.height/2)
            let radius = min(size.width, size.height) * 0.3
            
            // Energy ring
            context.stroke(
                Circle().path(in: CGRect(x: center.x - radius,
                                       y: center.y - radius,
                                       width: radius * 2,
                                       height: radius * 2)),
                with: .color(mood.color.opacity(0.3)),
                lineWidth: CGFloat(indicators.energy) * 20
            )
            
            // Complexity spikes
            let complexityPoints = (0...12).map { i -> CGPoint in
                let angle = Double(i) * .pi * 2 / 12
                let spikeLength = radius * (1 + CGFloat(indicators.complexity) * 0.3)
                return CGPoint(
                    x: center.x + cos(angle) * spikeLength,
                    y: center.y + sin(angle) * spikeLength
                )
            }
            
            for (i, point) in complexityPoints.enumerated() {
                if i > 0 {
                    context.stroke(
                        Path { path in
                            path.move(to: complexityPoints[i-1])
                            path.addLine(to: point)
                        },
                        with: .color(mood.color.opacity(0.2)),
                        lineWidth: 2
                    )
                }
            }
            
            // Density particles
            let particleCount = Int(indicators.density * 100)
            for _ in 0..<particleCount {
                let angle = Double.random(in: 0...(2 * .pi))
                let distance = Double.random(in: 0...Double(radius))
                let point = CGPoint(
                    x: center.x + cos(angle) * distance,
                    y: center.y + sin(angle) * distance
                )
                
                context.fill(
                    Circle().path(in: CGRect(x: point.x - 2,
                                           y: point.y - 2,
                                           width: 4,
                                           height: 4)),
                    with: .color(mood.color.opacity(0.3))
                )
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

// MARK: - ViewModel

class AudioVisualizationViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published private(set) var spectrum: [Float] = Array(repeating: 0, count: 50)
    @Published private(set) var currentMoodIndicators: MoodIndicators?
    
    private let moodEngine: MoodEngine
    private let fftProcessor = FFTProcessor()
    private let audioEngine = AVAudioEngine()
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(moodEngine: MoodEngine) {
        self.moodEngine = moodEngine
        setupAudioEngine()
    }
    
    // MARK: - Public Methods
    
    func updateVisualization() {
        guard let buffer = audioEngine.inputNode.outputFormat(forBus: 0).isCompressed else { return }
        
        // Get audio samples
        let samples = Array(buffer.floatChannelData?[0] ?? [])
        
        // Update spectrum
        spectrum = fftProcessor.getSpectrum(from: samples)
        
        // Update mood indicators
        let features = fftProcessor.extractFeatures(from: samples)
        currentMoodIndicators = features.moodIndicators()
    }
    
    // MARK: - Private Methods
    
    private func setupAudioEngine() {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            // Process audio buffer in real-time
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let samples = Array(UnsafeBufferPointer(start: channelData,
                                              count: Int(buffer.frameLength)))
        
        DispatchQueue.main.async {
            self.spectrum = self.fftProcessor.getSpectrum(from: samples)
            
            let features = self.fftProcessor.extractFeatures(from: samples)
            self.currentMoodIndicators = features.moodIndicators()
        }
    }
}

// MARK: - Preview

struct AudioVisualizationView_Previews: PreviewProvider {
    static var previews: some View {
        AudioVisualizationView(moodEngine: MoodEngine())
            .frame(height: 200)
            .padding()
    }
}
