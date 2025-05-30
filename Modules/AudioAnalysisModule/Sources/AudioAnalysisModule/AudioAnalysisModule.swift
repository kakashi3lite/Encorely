import Foundation
import AudioKit

public class AudioAnalysisModule {
    private let featureExtractor: FeatureExtractor
    private let windowSize: Int
    private let hopSize: Int
    
    public init?(windowSize: Int = 2048, hopSize: Int = 512, sampleRate: Double = 44100) {
        guard let extractor = FeatureExtractor(fftSize: windowSize, sampleRate: sampleRate) else {
            return nil
        }
        self.featureExtractor = extractor
        self.windowSize = windowSize
        self.hopSize = hopSize
    }
    
    /// Analyzes audio data and returns array of features for each window
    /// - Parameter samples: Array of audio samples (normalized float values)
    /// - Returns: Array of AudioFeatures, one for each analyzed window
    public func analyze(samples: [Float]) -> [AudioFeatures] {
        var features: [AudioFeatures] = []
        var startIndex = 0
        
        while startIndex + windowSize <= samples.count {
            let window = Array(samples[startIndex..<startIndex + windowSize])
            let windowFeatures = featureExtractor.extractFeatures(from: window)
            features.append(windowFeatures)
            startIndex += hopSize
        }
        
        return features
    }
    
    /// Analyzes a single window of audio data
    /// - Parameter samples: Array of audio samples (should match windowSize)
    /// - Returns: Extracted audio features for the window
    public func analyzeWindow(samples: [Float]) -> AudioFeatures? {
        guard samples.count == windowSize else { return nil }
        return featureExtractor.extractFeatures(from: samples)
    }
    
    /// Get the current window size used for analysis
    public var analysisWindowSize: Int {
        return windowSize
    }
    
    /// Get the current hop size used for analysis
    public var analysisHopSize: Int {
        return hopSize
    }
}
