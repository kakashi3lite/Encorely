import Foundation
import Accelerate
import AVFoundation

class FFTProcessor {
    private let fftSetup: vDSP_DFT_Setup?
    private let maxFrameSize: Int
    private let sampleRate: Float
    private var window: [Float]
    private let magnitudeNormalizationFactor: Float
    private var previousMagnitudes: [Float]?
    private var tempBuffer: [Float]
    
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
        
        // Initialize temp buffer
        self.tempBuffer = [Float](repeating: 0, count: maxFrameSize)
        
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
        
        // Calculate spectral flux if we have previous magnitudes
        var spectralFlux: Float = 0
        if let prevMags = previousMagnitudes, let mags = magnitudes {
            spectralFlux = calculateSpectralFlux(current: mags, previous: prevMags)
        }
        
        // Store current magnitudes for next frame
        previousMagnitudes = magnitudes
        
        // Extract spectral features
        return magnitudes.map { mags -> SpectralFeatures in
            var features = extractSpectralFeatures(from: mags)
            features.spectralFlux = spectralFlux
            return features
        }
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
        
        // Spectral features
        let centroid = calculateSpectralCentroid(magnitudes: magnitudes, frequencyResolution: frequencyResolution)
        let flatness = calculateSpectralFlatness(magnitudes: magnitudes)
        let rolloff = calculateSpectralRolloff(magnitudes: magnitudes, frequencyResolution: frequencyResolution)
        let brightness = calculateBrightness(magnitudes: magnitudes, frequencyResolution: frequencyResolution)
        let contrast = calculateSpectralContrast(bandEnergies: bandEnergies)
        let harmonicRatio = calculateHarmonicRatio(magnitudes: magnitudes, frequencyResolution: frequencyResolution)
        let zeroCrossingRate = calculateZeroCrossingRate(magnitudes: magnitudes)
        let crest = calculateSpectralCrest(magnitudes: magnitudes)
        
        return SpectralFeatures(
            bassEnergy: bandEnergies.bass,
            midEnergy: bandEnergies.mid,
            trebleEnergy: bandEnergies.treble,
            centroid: centroid,
            flatness: flatness,
            rolloff: rolloff,
            brightness: brightness,
            spectralContrast: contrast,
            harmonicRatio: harmonicRatio,
            zeroCrossingRate: zeroCrossingRate,
            spectralCrest: crest,
            dynamicRange: calculateDynamicRange(magnitudes: magnitudes),
            spectralFlux: 0 // Will be set later
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
        
        // Normalize
        let total = bass + mid + treble + Float.ulpOfOne
        return (bass/total, mid/total, treble/total)
    }
    
    private func calculateBrightness(magnitudes: [Float], frequencyResolution: Float) -> Float {
        let cutoffFreq: Float = 1000.0 // Typical brightness cutoff
        let cutoffBin = Int(cutoffFreq / frequencyResolution)
        
        var highFreqEnergy: Float = 0
        var totalEnergy: Float = 0
        
        vDSP_sve(magnitudes[cutoffBin...], 1, &highFreqEnergy, vDSP_Length(magnitudes.count - cutoffBin))
        vDSP_sve(magnitudes, 1, &totalEnergy, vDSP_Length(magnitudes.count))
        
        return highFreqEnergy / (totalEnergy + Float.ulpOfOne)
    }
    
    private func calculateSpectralFlux(current: [Float], previous: [Float]) -> Float {
        vDSP_vsub(previous, 1, current, 1, &tempBuffer, 1, vDSP_Length(min(current.count, previous.count)))
        vDSP_vabs(tempBuffer, 1, &tempBuffer, 1, vDSP_Length(min(current.count, previous.count)))
        
        var flux: Float = 0
        vDSP_sve(tempBuffer, 1, &flux, vDSP_Length(min(current.count, previous.count)))
        
        return flux / Float(current.count)
    }
    
    private func calculateSpectralCrest(magnitudes: [Float]) -> Float {
        var maxVal: Float = 0
        var mean: Float = 0
        
        vDSP_maxv(magnitudes, 1, &maxVal, vDSP_Length(magnitudes.count))
        vDSP_meanv(magnitudes, 1, &mean, vDSP_Length(magnitudes.count))
        
        return maxVal / (mean + Float.ulpOfOne)
    }
    
    private func calculateDynamicRange(magnitudes: [Float]) -> Float {
        var maxVal: Float = 0
        var minVal: Float = 0
        
        vDSP_maxv(magnitudes, 1, &maxVal, vDSP_Length(magnitudes.count))
        vDSP_minv(magnitudes, 1, &minVal, vDSP_Length(magnitudes.count))
        
        return maxVal - minVal
    }
    
    private func calculateZeroCrossingRate(magnitudes: [Float]) -> Float {
        var previousSign: Float = magnitudes[0] > 0 ? 1 : -1
        var crossings: Float = 0
        
        for i in 1..<magnitudes.count {
            let currentSign = magnitudes[i] > 0 ? 1 : -1
            if currentSign != previousSign {
                crossings += 1
            }
            previousSign = currentSign
        }
        
        return crossings / Float(magnitudes.count)
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
    let zeroCrossingRate: Float
    let spectralCrest: Float
    let dynamicRange: Float
    var spectralFlux: Float
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