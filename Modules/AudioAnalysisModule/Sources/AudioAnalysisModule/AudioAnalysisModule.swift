import Foundation
import AudioKit
import AVFoundation

public class AudioAnalysisModule {
    // Core components
    private let featureExtractor: FeatureExtractor
    private let windowSize: Int
    private let hopSize: Int
    
    // Analysis settings
    private let sampleRate: Double
    private let analysisQueue = DispatchQueue(label: "com.aimixtapes.audioanalysis",
                                            qos: .userInitiated)
    
    // AudioKit components
    private let engine = AudioEngine()
    private var audioPlayer: AudioPlayer?
    private var mixer: Mixer?
    private var eqMixer: Mixer?
    
    // Analysis nodes
    private var pitchTracker: PitchTap?
    private var fftAnalyzer: FFTTap?
    private var amplitudeTracker: AmplitudeTap?
    
    // Analysis callbacks
    public var onFeaturesExtracted: ((AudioFeatures) -> Void)?
    public var onAnalysisProgress: ((Double) -> Void)?
    public var onAnalysisError: ((Error) -> Void)?
    
    public init?(windowSize: Int = 2048, hopSize: Int = 512, sampleRate: Double = 44100) {
        guard let extractor = FeatureExtractor(fftSize: windowSize, sampleRate: sampleRate) else {
            return nil
        }
        
        self.featureExtractor = extractor
        self.windowSize = windowSize
        self.hopSize = hopSize
        self.sampleRate = sampleRate
        
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        // Create audio processing chain
        audioPlayer = AudioPlayer()
        mixer = Mixer()
        eqMixer = Mixer()
        
        if let player = audioPlayer, let mix = mixer, let eq = eqMixer {
            // Configure audio chain
            mix.addInput(player)
            eq.addInput(mix)
            engine.output = eq
            
            // Setup analysis taps
            setupAnalysisTaps(on: eq)
        }
        
        // Start engine
        do {
            try engine.start()
        } catch {
            print("Failed to start AudioKit engine: \(error)")
        }
    }
    
    private func setupAnalysisTaps(on node: Node) {
        // Setup pitch tracking
        pitchTracker = PitchTap(node) { [weak self] pitch, amp in
            guard let self = self else { return }
            // Process pitch data
        }
        
        // Setup FFT analysis
        fftAnalyzer = FFTTap(node) { [weak self] fftData in
            guard let self = self else { return }
            // Process FFT data
        }
        
        // Setup amplitude tracking
        amplitudeTracker = AmplitudeTap(node) { [weak self] amp in
            guard let self = self else { return }
            // Process amplitude data
        }
        
        // Start all taps
        pitchTracker?.start()
        fftAnalyzer?.start()
        amplitudeTracker?.start()
    }
    
    /// Analyzes audio data and returns array of features for each window
    /// - Parameter samples: Array of audio samples (normalized float values)
    /// - Returns: Array of AudioFeatures, one for each analyzed window
    public func analyze(samples: [Float]) -> [AudioFeatures] {
        var features: [AudioFeatures] = []
        var startIndex = 0
        let totalWindows = (samples.count - windowSize) / hopSize + 1
        
        while startIndex + windowSize <= samples.count {
            autoreleasepool {
                let window = Array(samples[startIndex..<startIndex + windowSize])
                if let windowFeatures = analyzeWindow(samples: window) {
                    features.append(windowFeatures)
                }
                
                // Report progress
                let progress = Double(features.count) / Double(totalWindows)
                DispatchQueue.main.async {
                    self.onAnalysisProgress?(progress)
                }
                
                startIndex += hopSize
            }
        }
        
        return features
    }
    
    /// Analyzes audio from a file
    /// - Parameter url: URL of the audio file to analyze
    /// - Returns: Array of extracted features
    public func analyzeFile(at url: URL) async throws -> [AudioFeatures] {
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            throw NSError(domain: "AudioAnalysis", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load audio file"])
        }
        
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        
        guard let buffer = buffer else {
            throw NSError(domain: "AudioAnalysis", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create audio buffer"])
        }
        
        try audioFile.read(into: buffer)
        
        // Convert to mono if needed and get samples
        let samples = buffer.toMonoArray()
        
        return analyze(samples: samples)
    }
    
    /// Analyzes a single window of audio data
    /// - Parameter samples: Array of audio samples (should match windowSize)
    /// - Returns: Extracted audio features for the window
    public func analyzeWindow(samples: [Float]) -> AudioFeatures? {
        guard samples.count == windowSize else { return nil }
        
        let features = featureExtractor.extractFeatures(from: samples)
        
        DispatchQueue.main.async {
            self.onFeaturesExtracted?(features)
        }
        
        return features
    }
    
    /// Start real-time analysis of audio input
    /// - Parameter input: Optional audio input node (uses default input if nil)
    public func startRealTimeAnalysis(input: Node? = nil) throws {
        // Configure input
        if let inputNode = input {
            mixer?.addInput(inputNode)
        }
        
        // Start engine if needed
        if !engine.avEngine.isRunning {
            try engine.start()
        }
        
        // Start analysis taps
        pitchTracker?.start()
        fftAnalyzer?.start()
        amplitudeTracker?.start()
    }
    
    /// Stop real-time analysis
    public func stopRealTimeAnalysis() {
        pitchTracker?.stop()
        fftAnalyzer?.stop()
        amplitudeTracker?.stop()
    }
    
    /// Get the current window size used for analysis
    public var analysisWindowSize: Int {
        return windowSize
    }
    
    /// Get the current hop size used for analysis
    public var analysisHopSize: Int {
        return hopSize
    }
    
    deinit {
        stopRealTimeAnalysis()
        engine.stop()
    }
}

// MARK: - AudioBuffer Extensions

extension AVAudioPCMBuffer {
    func toMonoArray() -> [Float] {
        let channels = Int(format.channelCount)
        let frameLength = Int(frameLength)
        let stride = format.channelCount
        
        guard let floatData = floatChannelData else {
            return []
        }
        
        // If already mono, just return the samples
        if channels == 1 {
            return Array(UnsafeBufferPointer(start: floatData[0], count: frameLength))
        }
        
        // Mix down to mono
        var monoSamples = [Float](repeating: 0, count: frameLength)
        
        for frame in 0..<frameLength {
            var sum: Float = 0
            for channel in 0..<channels {
                sum += floatData[channel][frame]
            }
            monoSamples[frame] = sum / Float(channels)
        }
        
        return monoSamples
    }
}
