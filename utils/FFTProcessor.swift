import Foundation
import Accelerate
import AVFoundation

final class FFTProcessor {
    // MARK: - Constants
    
    private enum Constants {
        static let fftSize = 2048
        static let hopSize = 512
        static let sampleRate = 44100
        static let numBands = 32
        static let minFrequency: Float = 20.0
        static let maxFrequency: Float = 20000.0
    }
    
    // MARK: - Properties
    
    private var fftSetup: vDSP_DFT_Setup?
    private var hanningWindow: [Float]
    private var frequencyBands: [FrequencyBand]
    private var splitComplex: DSPSplitComplex
    
    // MARK: - Initialization
    
    init() {
        // Create FFT setup
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(Constants.fftSize),
            vDSP_DFT_Direction.FORWARD
        )
        
        // Create Hanning window
        hanningWindow = [Float](repeating: 0, count: Constants.fftSize)
        vDSP_hann_window(&hanningWindow, UInt(Constants.fftSize), Int32(vDSP_HANN_NORM))
        
        // Initialize frequency bands
        frequencyBands = createFrequencyBands()
        
        // Initialize split complex buffer
        let real = [Float](repeating: 0, count: Constants.fftSize/2)
        let imag = [Float](repeating: 0, count: Constants.fftSize/2)
        splitComplex = DSPSplitComplex(realp: UnsafeMutablePointer(mutating: real),
                                     imagp: UnsafeMutablePointer(mutating: imag))
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
    
    // MARK: - Public Methods
    
    /// Process audio buffer and extract frequency features
    func extractFeatures(from samples: [Float]) -> AudioFeatures {
        // Apply window function
        var windowedSamples = [Float](repeating: 0, count: Constants.fftSize)
        vDSP_vmul(samples, 1, hanningWindow, 1, &windowedSamples, 1, UInt(min(samples.count, Constants.fftSize)))
        
        // Perform FFT
        var magnitudes = performFFT(samples: windowedSamples)
        
        // Convert to dB scale
        vDSP_vdbcon(magnitudes, 1, [1.0], &magnitudes, 1, UInt(magnitudes.count), Int32(1))
        
        // Calculate band energies
        let bandEnergies = calculateBandEnergies(magnitudes: magnitudes)
        
        // Extract features
        return AudioFeatures(
            energy: calculateEnergy(bandEnergies: bandEnergies),
            brightness: calculateBrightness(bandEnergies: bandEnergies),
            complexity: calculateComplexity(magnitudes: magnitudes),
            density: calculateDensity(magnitudes: magnitudes)
        )
    }
    
    /// Get current spectrum for visualization
    func getSpectrum(from samples: [Float], bands: Int = 50) -> [Float] {
        let magnitudes = performFFT(samples: samples)
        return resampleSpectrum(magnitudes: magnitudes, targetBands: bands)
    }
    
    // MARK: - Private Methods
    
    private func performFFT(samples: [Float]) -> [Float] {
        var realPart = [Float](repeating: 0, count: Constants.fftSize/2)
        var imagPart = [Float](repeating: 0, count: Constants.fftSize/2)
        
        // Pack samples into split complex format
        samples.withUnsafeBufferPointer { samplesPtr in
            vDSP_ctoz([DSPComplex](UnsafeRawPointer(samplesPtr.baseAddress!).assumingMemoryBound(to: DSPComplex.self)),
                      2,
                      &splitComplex,
                      1,
                      UInt(Constants.fftSize/2))
        }
        
        // Perform FFT
        vDSP_fft_zrip(fftSetup!, &splitComplex, 1, UInt(log2(Double(Constants.fftSize))), FFTDirection(FFT_FORWARD))
        
        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: Constants.fftSize/2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, UInt(Constants.fftSize/2))
        
        // Normalize
        var normalizer = 1.0 / Float(Constants.fftSize)
        vDSP_vsmul(magnitudes, 1, &normalizer, &magnitudes, 1, UInt(Constants.fftSize/2))
        
        return magnitudes
    }
    
    private func createFrequencyBands() -> [FrequencyBand] {
        let bandsPerOctave = 4
        let numOctaves = Int(log2(Constants.maxFrequency/Constants.minFrequency))
        let numBands = bandsPerOctave * numOctaves
        
        return (0..<numBands).map { i in
            let centerFreq = Constants.minFrequency * pow(2, Float(i) / Float(bandsPerOctave))
            let bandwidth = centerFreq * (pow(2, 1.0 / Float(2 * bandsPerOctave)) - 1)
            return FrequencyBand(
                centerFrequency: centerFreq,
                minFrequency: centerFreq - bandwidth,
                maxFrequency: centerFreq + bandwidth
            )
        }
    }
    
    private func calculateBandEnergies(magnitudes: [Float]) -> [Float] {
        return frequencyBands.map { band -> Float in
            let minBin = Int(band.minFrequency * Float(Constants.fftSize) / Float(Constants.sampleRate))
            let maxBin = Int(band.maxFrequency * Float(Constants.fftSize) / Float(Constants.sampleRate))
            let bandMagnitudes = Array(magnitudes[max(0, minBin)..<min(maxBin, magnitudes.count)])
            
            var sum: Float = 0
            vDSP_sve(bandMagnitudes, 1, &sum, UInt(bandMagnitudes.count))
            return sum / Float(bandMagnitudes.count)
        }
    }
    
    private func resampleSpectrum(magnitudes: [Float], targetBands: Int) -> [Float] {
        var output = [Float](repeating: 0, count: targetBands)
        let scale = Float(magnitudes.count) / Float(targetBands)
        
        for i in 0..<targetBands {
            let start = Int(Float(i) * scale)
            let end = Int(Float(i + 1) * scale)
            let samples = Array(magnitudes[start..<end])
            
            var average: Float = 0
            vDSP_meanv(samples, 1, &average, UInt(samples.count))
            output[i] = average
        }
        
        return output
    }
    
    private func calculateEnergy(bandEnergies: [Float]) -> Float {
        var sum: Float = 0
        vDSP_sve(bandEnergies, 1, &sum, UInt(bandEnergies.count))
        return sum / Float(bandEnergies.count)
    }
    
    private func calculateBrightness(bandEnergies: [Float]) -> Float {
        let highFreqStartIndex = frequencyBands.firstIndex { $0.centerFrequency >= 2000 } ?? 0
        let highFreqEnergies = Array(bandEnergies[highFreqStartIndex...])
        
        var highSum: Float = 0
        vDSP_sve(highFreqEnergies, 1, &highSum, UInt(highFreqEnergies.count))
        
        var totalSum: Float = 0
        vDSP_sve(bandEnergies, 1, &totalSum, UInt(bandEnergies.count))
        
        return highSum / totalSum
    }
    
    private func calculateComplexity(magnitudes: [Float]) -> Float {
        var diff = [Float](repeating: 0, count: magnitudes.count - 1)
        vDSP_vdiff(magnitudes, 1, &diff, 1, UInt(diff.count))
        
        var sum: Float = 0
        vDSP_svesq(diff, 1, &sum, UInt(diff.count))
        
        return sqrt(sum / Float(diff.count))
    }
    
    private func calculateDensity(magnitudes: [Float]) -> Float {
        let threshold = -60.0 // dB
        let activeBins = magnitudes.filter { $0 > Float(threshold) }.count
        return Float(activeBins) / Float(magnitudes.count)
    }
}

// MARK: - Supporting Types

struct FrequencyBand {
    let centerFrequency: Float
    let minFrequency: Float
    let maxFrequency: Float
}

struct AudioFeatures {
    let energy: Float      // Overall energy level (0-1)
    let brightness: Float  // High frequency content (0-1)
    let complexity: Float  // Spectral complexity (0-1)
    let density: Float     // Spectral density (0-1)
    
    func moodIndicators() -> MoodIndicators {
        return MoodIndicators(
            energy: energy,
            brightness: brightness,
            complexity: complexity,
            density: density
        )
    }
}

struct MoodIndicators {
    let energy: Float      // Overall energy level
    let brightness: Float  // Positive/negative emotion correlation
    let complexity: Float  // Musical complexity
    let density: Float     // Textural density
}
