import Foundation
import Accelerate

// Frequency bands for spectral analysis
public struct FrequencyBands {
    static let bass = (20.0, 250.0)    // Bass range
    static let mid = (250.0, 4000.0)   // Mid range
    static let treble = (4000.0, 20000.0) // Treble range
}

public struct SpectralFeatures {
    public let centroid: Float      // Brightness of the sound
    public let spread: Float        // Bandwidth of the spectrum
    public let flux: Float          // Rate of spectral change
    public let flatness: Float      // Tonal vs noisy
    public let rolloff: Float       // Frequency below which 85% of spectrum energy lies
    public let brightness: Float    // High frequency energy ratio
    public let bassEnergy: Float   
    public let midEnergy: Float
    public let trebleEnergy: Float
    public let harmonicRatio: Float // Ratio of harmonic to non-harmonic content
    public let spectralContrast: Float
}

public class FFTProcessor {
    private let fftSetup: vDSP_DFT_Setup
    private let log2n: UInt
    private let n: UInt
    private let sampleRate: Float
    private var previousSpectrum: [Float]?
    
    public init?(size: Int, sampleRate: Float = 44100) {
        guard let log2n = UInt(exactly: log2(Double(size))) else { return nil }
        self.log2n = log2n
        self.n = UInt(size)
        self.sampleRate = sampleRate
        
        guard let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(size), vDSP_DFT_FORWARD) else {
            return nil
        }
        self.fftSetup = setup
    }
    
    deinit {
        vDSP_DFT_DestroySetup(fftSetup)
    }
    
    public func performFFT(on samples: [Float]) -> [Float] {
        var realIn = [Float](repeating: 0.0, count: Int(n))
        var imagIn = [Float](repeating: 0.0, count: Int(n))
        var realOut = [Float](repeating: 0.0, count: Int(n))
        var imagOut = [Float](repeating: 0.0, count: Int(n))
        
        // Copy input samples
        realIn.replaceSubrange(0..<min(samples.count, Int(n)), with: samples[0..<min(samples.count, Int(n))])
        
        // Apply Hanning window
        var window = [Float](repeating: 0.0, count: Int(n))
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        vDSP_vmul(realIn, 1, window, 1, &realIn, 1, vDSP_Length(n))
        
        // Perform FFT
        vDSP_DFT_Execute(fftSetup,
                        realIn.withUnsafeBufferPointer { $0.baseAddress! },
                        imagIn.withUnsafeBufferPointer { $0.baseAddress! },
                        realOut.withUnsafeBufferPointer { $0.baseAddress! },
                        imagOut.withUnsafeBufferPointer { $0.baseAddress! })
        
        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0.0, count: Int(n))
        vDSP_zvmags(&realOut, 1, &magnitudes, 1, vDSP_Length(n/2))
        
        // Convert to dB scale
        var scaledMagnitudes = [Float](repeating: 0.0, count: Int(n/2))
        var zero: Float = 1e-6 // To avoid log of zero
        vDSP_vdbcon(magnitudes, 1, &zero, &scaledMagnitudes, 1, vDSP_Length(n/2), 1)
        
        return scaledMagnitudes
    }
    
    public func analyzeSpectralFeatures(_ buffer: AVAudioPCMBuffer) -> SpectralFeatures? {
        guard let channelData = buffer.floatChannelData?[0],
              buffer.frameLength > 0 else {
            return nil
        }
        
        let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let spectrum = performFFT(on: samples)
        
        // Frequency resolution
        let freqRes = sampleRate / Float(n)
        
        // Calculate spectral features
        let centroid = calculateSpectralCentroid(spectrum: spectrum, freqRes: freqRes)
        let spread = calculateSpectralSpread(spectrum: spectrum, centroid: centroid, freqRes: freqRes)
        let flux = calculateSpectralFlux(spectrum: spectrum)
        let flatness = calculateSpectralFlatness(spectrum: spectrum)
        let rolloff = calculateSpectralRolloff(spectrum: spectrum, freqRes: freqRes)
        let brightness = calculateBrightness(spectrum: spectrum, freqRes: freqRes)
        
        // Calculate band energies
        let bandEnergies = calculateBandEnergies(spectrum: spectrum, freqRes: freqRes)
        
        // Calculate harmonic features
        let harmonicRatio = calculateHarmonicRatio(spectrum: spectrum)
        let spectralContrast = calculateSpectralContrast(spectrum: spectrum)
        
        // Store spectrum for flux calculation
        previousSpectrum = spectrum
        
        return SpectralFeatures(
            centroid: centroid,
            spread: spread,
            flux: flux,
            flatness: flatness,
            rolloff: rolloff,
            brightness: brightness,
            bassEnergy: bandEnergies.bass,
            midEnergy: bandEnergies.mid,
            trebleEnergy: bandEnergies.treble,
            harmonicRatio: harmonicRatio,
            spectralContrast: spectralContrast
        )
    }
    
    private func calculateSpectralCentroid(spectrum: [Float], freqRes: Float) -> Float {
        var weightedSum: Float = 0.0
        var totalEnergy: Float = 0.0
        
        for (i, magnitude) in spectrum.enumerated() {
            let frequency = Float(i) * freqRes
            weightedSum += frequency * magnitude
            totalEnergy += magnitude
        }
        
        return totalEnergy > 0 ? weightedSum / totalEnergy : 0
    }
    
    private func calculateSpectralSpread(spectrum: [Float], centroid: Float, freqRes: Float) -> Float {
        var variance: Float = 0.0
        var totalEnergy: Float = 0.0
        
        for (i, magnitude) in spectrum.enumerated() {
            let frequency = Float(i) * freqRes
            let diff = frequency - centroid
            variance += diff * diff * magnitude
            totalEnergy += magnitude
        }
        
        return totalEnergy > 0 ? sqrt(variance / totalEnergy) : 0
    }
    
    private func calculateSpectralFlux(spectrum: [Float]) -> Float {
        guard let previous = previousSpectrum else { return 0 }
        
        var sum: Float = 0.0
        let count = min(spectrum.count, previous.count)
        
        for i in 0..<count {
            let diff = spectrum[i] - previous[i]
            sum += diff * diff
        }
        
        return sqrt(sum)
    }
    
    private func calculateSpectralFlatness(spectrum: [Float]) -> Float {
        let epsilon: Float = 1e-6
        var geometricMean: Float = 0.0
        var arithmeticMean: Float = 0.0
        
        for magnitude in spectrum {
            let value = magnitude + epsilon
            geometricMean += log(value)
            arithmeticMean += value
        }
        
        geometricMean = exp(geometricMean / Float(spectrum.count))
        arithmeticMean /= Float(spectrum.count)
        
        return geometricMean / arithmeticMean
    }
    
    private func calculateSpectralRolloff(spectrum: [Float], freqRes: Float) -> Float {
        let threshold: Float = 0.85
        let totalEnergy = spectrum.reduce(0, +)
        var sum: Float = 0.0
        
        for (i, magnitude) in spectrum.enumerated() {
            sum += magnitude
            if sum >= totalEnergy * threshold {
                return Float(i) * freqRes
            }
        }
        
        return 0
    }
    
    private func calculateBrightness(spectrum: [Float], freqRes: Float) -> Float {
        let cutoffFreq: Float = 1500.0 // Standard brightness cutoff
        let cutoffBin = Int(cutoffFreq / freqRes)
        let highFreqEnergy = spectrum[cutoffBin...].reduce(0, +)
        let totalEnergy = spectrum.reduce(0, +)
        
        return totalEnergy > 0 ? highFreqEnergy / totalEnergy : 0
    }
    
    private func calculateBandEnergies(spectrum: [Float], freqRes: Float) -> (bass: Float, mid: Float, treble: Float) {
        let bassBins = (Int(FrequencyBands.bass.0 / Double(freqRes))...Int(FrequencyBands.bass.1 / Double(freqRes)))
        let midBins = (Int(FrequencyBands.mid.0 / Double(freqRes))...Int(FrequencyBands.mid.1 / Double(freqRes)))
        let trebleBins = (Int(FrequencyBands.treble.0 / Double(freqRes))...Int(FrequencyBands.treble.1 / Double(freqRes)))
        
        let bassEnergy = bassBins.reduce(0) { $0 + (spectrum[safe: $1] ?? 0) }
        let midEnergy = midBins.reduce(0) { $0 + (spectrum[safe: $1] ?? 0) }
        let trebleEnergy = trebleBins.reduce(0) { $0 + (spectrum[safe: $1] ?? 0) }
        
        return (bassEnergy, midEnergy, trebleEnergy)
    }
    
    private func calculateHarmonicRatio(spectrum: [Float]) -> Float {
        var harmonicEnergy: Float = 0
        var nonHarmonicEnergy: Float = 0
        
        for (i, magnitude) in spectrum.enumerated() {
            if isHarmonicBin(bin: i) {
                harmonicEnergy += magnitude
            } else {
                nonHarmonicEnergy += magnitude
            }
        }
        
        return (nonHarmonicEnergy + 1e-6) > 0 ? harmonicEnergy / (nonHarmonicEnergy + 1e-6) : 0
    }
    
    private func isHarmonicBin(bin: Int) -> Bool {
        // Consider frequencies that are integer multiples of the fundamental
        let fundamentalBin = 2 // Assuming fundamental frequency around 86Hz at 44.1kHz
        let tolerance = 0.1 // 10% tolerance for harmonic detection 
        
        for harmonic in 1...8 {
            let expectedBin = fundamentalBin * harmonic
            let lowerBound = Float(expectedBin) * (1 - tolerance)
            let upperBound = Float(expectedBin) * (1 + tolerance)
            
            if Float(bin) >= lowerBound && Float(bin) <= upperBound {
                return true
            }
        }
        
        return false
    }
    
    private func calculateSpectralContrast(spectrum: [Float]) -> Float {
        let numBands = 6
        let bandSize = spectrum.count / numBands
        var contrast: Float = 0
        
        for i in 0..<numBands {
            let start = i * bandSize
            let end = start + bandSize
            let band = Array(spectrum[start..<end])
            
            // Get difference between peaks and valleys
            let sorted = band.sorted()
            let peakAvg = sorted.suffix(3).reduce(0, +) / 3
            let valleyAvg = sorted.prefix(3).reduce(0, +) / 3
            
            contrast += (peakAvg - valleyAvg)
        }
        
        return contrast / Float(numBands)
    }
}

// MARK: - Helper Extensions

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
