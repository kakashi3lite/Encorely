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
        // Define frequency bands (in Hz)
        let bassRange = (20.0...250.0)
        let midRange = (250.0...4000.0)
        let trebleRange = (4000.0...20000.0)
        
        // Convert frequencies to bin indices
        let bassIndices = (Int(bassRange.lowerBound / Float(frequencyResolution))...Int(bassRange.upperBound / Float(frequencyResolution)))
        let midIndices = (Int(midRange.lowerBound / Float(frequencyResolution))...Int(midRange.upperBound / Float(frequencyResolution)))
        let trebleIndices = (Int(trebleRange.lowerBound / Float(frequencyResolution))...Int(trebleRange.upperBound / Float(frequencyResolution)))
        
        // Calculate energy in each band
        var bassEnergy: Float = 0
        var midEnergy: Float = 0
        var trebleEnergy: Float = 0
        
        for i in 0..<magnitudes.count {
            if bassIndices.contains(i) {
                bassEnergy += magnitudes[i]
            } else if midIndices.contains(i) {
                midEnergy += magnitudes[i]
            } else if trebleIndices.contains(i) {
                trebleEnergy += magnitudes[i]
            }
        }
        
        // Normalize energies
        let totalEnergy = bassEnergy + midEnergy + trebleEnergy + Float.ulpOfOne
        return (
            bass: bassEnergy / totalEnergy,
            mid: midEnergy / totalEnergy,
            treble: trebleEnergy / totalEnergy
        )
    }
    
    private func calculateSpectralCentroid(magnitudes: [Float], frequencyResolution: Float) -> Float {
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        
        for (i, magnitude) in magnitudes.enumerated() {
            let frequency = Float(i) * frequencyResolution
            weightedSum += frequency * magnitude
            magnitudeSum += magnitude
        }
        
        return weightedSum / (magnitudeSum + Float.ulpOfOne)
    }
    
    private func calculateSpectralFlatness(magnitudes: [Float]) -> Float {
        let nonZeroMagnitudes = magnitudes.filter { $0 > Float.ulpOfOne }
        guard !nonZeroMagnitudes.isEmpty else { return 0 }
        
        let geometricMean = exp(nonZeroMagnitudes.map { log($0) }.reduce(0, +) / Float(nonZeroMagnitudes.count))
        let arithmeticMean = nonZeroMagnitudes.reduce(0, +) / Float(nonZeroMagnitudes.count)
        
        return geometricMean / (arithmeticMean + Float.ulpOfOne)
    }
    
    private func calculateSpectralRolloff(magnitudes: [Float], frequencyResolution: Float, percentile: Float = 0.85) -> Float {
        let totalEnergy = magnitudes.reduce(0, +)
        let targetEnergy = totalEnergy * percentile
        
        var cumulativeEnergy: Float = 0
        for (i, magnitude) in magnitudes.enumerated() {
            cumulativeEnergy += magnitude
            if cumulativeEnergy >= targetEnergy {
                return Float(i) * frequencyResolution
            }
        }
        
        return Float(magnitudes.count - 1) * frequencyResolution
    }
    
    private func calculateHarmonicRatio(magnitudes: [Float], frequencyResolution: Float) -> Float {
        let fundamentalRange = 50.0...500.0 // Typical fundamental frequency range
        let harmonicRatios = [2.0, 3.0, 4.0, 5.0] // Harmonic frequency ratios
        
        var maxHarmonicEnergy: Float = 0
        var totalEnergy: Float = magnitudes.reduce(0, +)
        
        for fundamental in stride(from: fundamentalRange.lowerBound, through: fundamentalRange.upperBound, by: frequencyResolution) {
            let fundamentalBin = Int(fundamental / frequencyResolution)
            var harmonicEnergy: Float = magnitudes[safe: fundamentalBin] ?? 0
            
            for ratio in harmonicRatios {
                let harmonicBin = Int(fundamental * ratio / frequencyResolution)
                if harmonicBin < magnitudes.count {
                    harmonicEnergy += magnitudes[harmonicBin]
                }
            }
            
            maxHarmonicEnergy = max(maxHarmonicEnergy, harmonicEnergy)
        }
        
        return maxHarmonicEnergy / (totalEnergy + Float.ulpOfOne)
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