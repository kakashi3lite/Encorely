import Foundation
import AudioKit
import Accelerate

public class FeatureExtractor {
    private let fftProcessor: FFTProcessor
    private let fftSize: Int
    private let sampleRate: Double
    
    public init?(fftSize: Int = 2048, sampleRate: Double = 44100) {
        guard let processor = FFTProcessor(size: fftSize) else { return nil }
        self.fftProcessor = processor
        self.fftSize = fftSize
        self.sampleRate = sampleRate
    }
    
    public func extractFeatures(from samples: [Float]) -> AudioFeatures {
        let rms = calculateRMS(samples)
        let zcr = calculateZeroCrossingRate(samples)
        let spectrum = fftProcessor.performFFT(on: samples)
        let centroid = calculateSpectralCentroid(spectrum)
        let rolloff = calculateSpectralRolloff(spectrum)
        let mfcc = calculateMFCC(spectrum)
        
        return AudioFeatures(
            rms: rms,
            zeroCrossingRate: zcr,
            spectralCentroid: centroid,
            spectralRolloff: rolloff,
            mfcc: mfcc
        )
    }
    
    private func calculateRMS(_ samples: [Float]) -> Float {
        var squareSum: Float = 0.0
        vDSP_vsq(samples, 1, &squareSum, 1, vDSP_Length(samples.count))
        return sqrt(squareSum / Float(samples.count))
    }
    
    private func calculateZeroCrossingRate(_ samples: [Float]) -> Float {
        var count: Float = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0 && samples[i-1] < 0) ||
               (samples[i] < 0 && samples[i-1] >= 0) {
                count += 1
            }
        }
        return count / Float(samples.count)
    }
    
    private func calculateSpectralCentroid(_ spectrum: [Float]) -> Float {
        let frequencies = (0..<spectrum.count).map { Float($0) * Float(sampleRate) / Float(fftSize) }
        var numerator: Float = 0
        var denominator: Float = 0
        
        vDSP_dotpr(frequencies, 1, spectrum, 1, &numerator, vDSP_Length(spectrum.count))
        vDSP_sve(spectrum, 1, &denominator, vDSP_Length(spectrum.count))
        
        return numerator / (denominator + 1e-6)
    }
    
    private func calculateSpectralRolloff(_ spectrum: [Float]) -> Float {
        let threshold: Float = 0.85
        var sum: Float = 0
        vDSP_sve(spectrum, 1, &sum, vDSP_Length(spectrum.count))
        
        var cumsum: Float = 0
        for (i, magnitude) in spectrum.enumerated() {
            cumsum += magnitude
            if cumsum >= sum * threshold {
                return Float(i) * Float(sampleRate) / Float(fftSize)
            }
        }
        return 0
    }
    
    private func calculateMFCC(_ spectrum: [Float]) -> [Float] {
        // Simple MFCC implementation - in practice, you might want to use AudioKit's built-in MFCC
        // or implement a more sophisticated version
        let numCoefficients = 13
        var mfcc = [Float](repeating: 0, count: numCoefficients)
        
        // This is a simplified version - real implementation would use mel filterbanks
        // and discrete cosine transform
        for i in 0..<numCoefficients {
            var sum: Float = 0
            for (j, magnitude) in spectrum.enumerated() {
                let freq = Float(j) * Float(sampleRate) / Float(fftSize)
                sum += magnitude * cos(Float.pi * Float(i) * freq / (Float(sampleRate) / 2.0))
            }
            mfcc[i] = sum / Float(spectrum.count)
        }
        
        return mfcc
    }
}
