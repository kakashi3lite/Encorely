import Foundation
import Accelerate
import AVFoundation

class FFTProcessor {
    private let fftSetup: vDSP_DFT_Setup?
    private let maxFrameSize: Int
    private let sampleRate: Float
    private var window: [Float]
    private let magnitudeNormalizationFactor: Float
    
    init(maxFrameSize: Int, sampleRate: Float = 44100.0) {
        self.maxFrameSize = maxFrameSize
        self.sampleRate = sampleRate
        self.fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(maxFrameSize),
            vDSP_DFT_Direction.FORWARD
        )
        
        // Initialize Hanning window
        self.window = [Float](repeating: 0, count: maxFrameSize)
        vDSP_hann_window(&self.window, vDSP_Length(maxFrameSize), Int32(vDSP_HANN_NORM))
        
        // Calculate normalization factor for magnitude spectrum
        self.magnitudeNormalizationFactor = 2.0 / Float(maxFrameSize)
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
    
    func processBuffer(_ buffer: AVAudioPCMBuffer) -> SpectralFeatures? {
        guard let channelData = buffer.floatChannelData?[0],
              buffer.frameLength > 0 else {
            return nil
        }
        
        // Get magnitude spectrum
        let magnitudes = try? getMagnitudeSpectrum(from: channelData, frameCount: Int(buffer.frameLength))
        
        // Extract spectral features
        return magnitudes.map { extractSpectralFeatures(from: $0) }
    }
    
    private func getMagnitudeSpectrum(from samples: UnsafePointer<Float>, frameCount: Int) throws -> [Float] {
        var realPart = [Float](repeating: 0, count: maxFrameSize)
        var imagPart = [Float](repeating: 0, count: maxFrameSize)
        
        // Copy samples and apply window
        samples.withMemoryRebound(to: Float.self, capacity: frameCount) { ptr in
            realPart.withUnsafeMutableBufferPointer { realPtr in
                realPtr.baseAddress?.initialize(from: ptr, count: min(frameCount, maxFrameSize))
            }
        }
        
        vDSP_vmul(realPart, 1, window, 1, &realPart, 1, vDSP_Length(maxFrameSize))
        
        // Perform FFT
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        
        guard let fftSetup = fftSetup else {
            throw AudioAnalysisError.bufferProcessingFailed("FFT setup not initialized")
        }
        
        vDSP_DFT_Execute(fftSetup, &realPart, &imagPart, &splitComplex.realp, &splitComplex.imagp)
        
        // Calculate magnitude spectrum
        let halfFrameCount = maxFrameSize / 2
        var magnitudes = [Float](repeating: 0, count: halfFrameCount)
        
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfFrameCount))
        vDSP_vsmul(magnitudes, 1, &magnitudeNormalizationFactor, &magnitudes, 1, vDSP_Length(halfFrameCount))
        
        return magnitudes
    }
    
    private func extractSpectralFeatures(from magnitudes: [Float]) -> SpectralFeatures {
        let binCount = vDSP_Length(magnitudes.count)
        let frequencyResolution = sampleRate / Float(maxFrameSize)
        
        // Calculate frequency bands
        let bandEnergies = calculateBandEnergies(magnitudes: magnitudes, frequencyResolution: frequencyResolution)
        
        // Spectral centroid
        let centroid = calculateSpectralCentroid(magnitudes: magnitudes, frequencyResolution: frequencyResolution)
        
        // Spectral flatness
        let flatness = calculateSpectralFlatness(magnitudes: magnitudes)
        
        // Spectral rolloff
        let rolloff = calculateSpectralRolloff(magnitudes: magnitudes, frequencyResolution: frequencyResolution)
        
        // Additional features
        let brightness = bandEnergies.treble / (bandEnergies.bass + bandEnergies.mid + 1e-6)
        let contrast = max(bandEnergies.bass, bandEnergies.treble) / (bandEnergies.mid + 1e-6)
        let harmonicRatio = calculateHarmonicRatio(magnitudes: magnitudes, frequencyResolution: frequencyResolution)
        
        return SpectralFeatures(
            bassEnergy: bandEnergies.bass,
            midEnergy: bandEnergies.mid,
            trebleEnergy: bandEnergies.treble,
            centroid: centroid,
            flatness: flatness,
            rolloff: rolloff,
            brightness: brightness,
            spectralContrast: contrast,
            harmonicRatio: harmonicRatio
        )
    }
    
    private func calculateBandEnergies(magnitudes: [Float], frequencyResolution: Float) -> (bass: Float, mid: Float, treble: Float) {
        let bassRange = (20.0, 250.0)
        let midRange = (250.0, 4000.0)
        let trebleRange = (4000.0, sampleRate/2)
        
        let bass = calculateBandEnergy(magnitudes: magnitudes,
                                     frequencyRange: bassRange,
                                     frequencyResolution: frequencyResolution)
        
        let mid = calculateBandEnergy(magnitudes: magnitudes,
                                    frequencyRange: midRange,
                                    frequencyResolution: frequencyResolution)
        
        let treble = calculateBandEnergy(magnitudes: magnitudes,
                                       frequencyRange: trebleRange,
                                       frequencyResolution: frequencyResolution)
        
        return (bass, mid, treble)
    }
    
    private func calculateSpectralCentroid(magnitudes: [Float], frequencyResolution: Float) -> Float {
        let frequencies = [Float](0..<Float(magnitudes.count)).map { $0 * frequencyResolution }
        
        var weightedSum: Float = 0
        var sum: Float = 0
        
        vDSP_dotpr(magnitudes, 1, frequencies, 1, &weightedSum, vDSP_Length(magnitudes.count))
        vDSP_sve(magnitudes, 1, &sum, vDSP_Length(magnitudes.count))
        
        return weightedSum / (sum + 1e-6)
    }
    
    private func calculateSpectralFlatness(magnitudes: [Float]) -> Float {
        var logMagnitudes = magnitudes
        vvlogf(&logMagnitudes, magnitudes, [Int32(magnitudes.count)])
        
        var geometricMean: Float = 0
        var arithmeticMean: Float = 0
        
        vDSP_meanv(logMagnitudes, 1, &geometricMean, vDSP_Length(magnitudes.count))
        vDSP_meanv(magnitudes, 1, &arithmeticMean, vDSP_Length(magnitudes.count))
        
        return exp(geometricMean) / (arithmeticMean + 1e-6)
    }
    
    private func calculateSpectralRolloff(magnitudes: [Float], frequencyResolution: Float) -> Float {
        let rolloffRatio: Float = 0.85
        var totalEnergy: Float = 0
        vDSP_sve(magnitudes, 1, &totalEnergy, vDSP_Length(magnitudes.count))
        
        let targetEnergy = totalEnergy * rolloffRatio
        var cumulativeEnergy: Float = 0
        
        for (bin, magnitude) in magnitudes.enumerated() {
            cumulativeEnergy += magnitude
            if cumulativeEnergy >= targetEnergy {
                return Float(bin) * frequencyResolution
            }
        }
        
        return 0
    }
    
    private func calculateBandEnergy(magnitudes: [Float],
                                   frequencyRange: (Float, Float),
                                   frequencyResolution: Float) -> Float {
        let startBin = Int(frequencyRange.0 / frequencyResolution)
        let endBin = min(Int(frequencyRange.1 / frequencyResolution), magnitudes.count)
        
        guard startBin < endBin && startBin >= 0 else { return 0 }
        
        var bandEnergy: Float = 0
        vDSP_sve(magnitudes[startBin..<endBin], 1, &bandEnergy,
                 vDSP_Length(endBin - startBin))
        
        return bandEnergy
    }
    
    private func calculateHarmonicRatio(magnitudes: [Float],
                                      frequencyResolution: Float) -> Float {
        let fundamentalRange = (80.0, 1000.0) // Typical fundamental frequency range
        let startBin = Int(fundamentalRange.0 / frequencyResolution)
        let endBin = Int(fundamentalRange.1 / frequencyResolution)
        
        guard startBin < endBin && startBin >= 0 && endBin < magnitudes.count else {
            return 0
        }
        
        // Find potential fundamental frequency
        var maxMagnitude: Float = 0
        var fundamentalBin = 0
        
        vDSP_maxvi(magnitudes[startBin..<endBin], 1, &maxMagnitude,
                   &fundamentalBin, vDSP_Length(endBin - startBin))
        fundamentalBin += startBin
        
        // Calculate energy in harmonic bins
        var harmonicEnergy: Float = 0
        var nonHarmonicEnergy: Float = 0
        
        for bin in startBin..<min(magnitudes.count, endBin * 5) {
            let frequency = Float(bin) * frequencyResolution
            let fundamentalFreq = Float(fundamentalBin) * frequencyResolution
            
            // Check if this bin is close to a harmonic
            let isHarmonic = (0...5).contains { harmonic in
                let harmonicFreq = fundamentalFreq * Float(harmonic + 1)
                return abs(frequency - harmonicFreq) < frequencyResolution * 2
            }
            
            if isHarmonic {
                harmonicEnergy += magnitudes[bin]
            } else {
                nonHarmonicEnergy += magnitudes[bin]
            }
        }
        
        return harmonicEnergy / (nonHarmonicEnergy + 1e-6)
    }
}

struct SpectralFeatures {
    let bassEnergy: Float
    let midEnergy: Float
    let trebleEnergy: Float
    let centroid: Float
    let flatness: Float
    let rolloff: Float
    let brightness: Float
    let spectralContrast: Float
    let harmonicRatio: Float
}

// MARK: - Supporting Types

struct FrequencyBand {
    let centerFrequency: Float
    let minFrequency: Float
    let maxFrequency: Float
}

struct AudioFeatures {
    let tempo: Float
    let energy: Float
    let spectralCentroid: Float
    let valence: Float
    let danceability: Float
    let acousticness: Float
    let instrumentalness: Float
    let speechiness: Float
    let liveness: Float
    
    func moodIndicators() -> MoodIndicators {
        return MoodIndicators(
            energy: energy,
            brightness: spectralCentroid,
            complexity: valence,
            density: danceability
        )
    }
}

struct MoodIndicators {