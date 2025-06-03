import Foundation
import AudioKit
import Accelerate
import SoundpipeAudioKit

public class FeatureExtractor {
    private let fftProcessor: FFTProcessor
    private let fftSize: Int
    private let sampleRate: Double
    
    // AudioKit nodes
    private let engine = AudioEngine()
    private var pitchTap: PitchTap?
    private var fftTap: FFTTap?
    private var amplitudeTap: AmplitudeTap?
    private var playerNode: AudioPlayer?
    
    private let analysisFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
    
    public init?(fftSize: Int = 2048, sampleRate: Double = 44100) {
        guard let processor = FFTProcessor(size: fftSize) else { return nil }
        self.fftProcessor = processor
        self.fftSize = fftSize
        self.sampleRate = sampleRate
        
        setupAudioKit()
    }
    
    private func setupAudioKit() {
        // Initialize player node
        playerNode = AudioPlayer()
        
        // Connect nodes
        if let player = playerNode {
            engine.output = player
            
            // Initialize analysis taps
            pitchTap = PitchTap(player) { pitch, amp in 
                // Process pitch data in real-time
            }
            
            fftTap = FFTTap(player) { fftData in
                // Process FFT data in real-time
            }
            
            amplitudeTap = AmplitudeTap(player) { amp in
                // Process amplitude data in real-time
            }
            
            // Start the taps
            pitchTap?.start()
            fftTap?.start()
            amplitudeTap?.start()
        }
        
        // Start the engine
        do {
            try engine.start()
        } catch {
            print("AudioKit engine failed to start: \(error.localizedDescription)")
        }
    }
    
    public func extractFeatures(from samples: [Float]) -> AudioFeatures {
        let rms = calculateAmplitude(samples)
        let (pitch, confidence) = calculatePitch(samples)
        let spectrum = calculateSpectrum(samples)
        let centroid = calculateSpectralCentroid(spectrum)
        let flatness = calculateSpectralFlatness(spectrum)
        let rolloff = calculateSpectralRolloff(spectrum)
        let spread = calculateSpectralSpread(spectrum, centroid: centroid)
        let bandEnergies = calculateBandEnergies(spectrum)
        
        return AudioFeatures(
            rms: rms,
            zeroCrossingRate: calculateZeroCrossingRate(samples),
            spectralCentroid: centroid,
            spectralRolloff: rolloff,
            spectralFlatness: flatness,
            spectralSpread: spread,
            pitch: pitch,
            pitchConfidence: confidence,
            bassEnergy: bandEnergies.bass,
            midEnergy: bandEnergies.mid,
            trebleEnergy: bandEnergies.treble,
            mfcc: calculateMFCC(spectrum)
        )
    }
    
    private func calculateAmplitude(_ samples: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms
    }
    
    private func calculatePitch(_ samples: [Float]) -> (pitch: Float, confidence: Float) {
        // Use AudioKit's pitch tracking
        guard let pitchTracker = try? PitchTap(engine.output) { pitch, amp in } else {
            return (0, 0)
        }
        
        var detectedPitch: Float = 0
        var detectedConfidence: Float = 0
        
        pitchTracker.callbackQueue = DispatchQueue.global(qos: .userInitiated)
        pitchTracker.start()
        
        // Process a small window for pitch detection
        let semaphore = DispatchSemaphore(value: 0)
        pitchTracker.handler = { pitch, amp in
            detectedPitch = pitch[0]
            detectedConfidence = amp[0]
            semaphore.signal()
        }
        
        // Wait for pitch detection with timeout
        let timeoutResult = semaphore.wait(timeout: .now() + 0.1)
        pitchTracker.stop()
        
        return timeoutResult == .success ? (detectedPitch, detectedConfidence) : (0, 0)
    }
    
    private func calculateSpectrum(_ samples: [Float]) -> [Float] {
        // Use AudioKit's FFT implementation for more accurate results
        guard let fft = try? FFTTap(engine.output) { _ in } else {
            return fftProcessor.performFFT(on: samples)
        }
        
        var fftData: [Float] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        fft.callbackQueue = DispatchQueue.global(qos: .userInitiated)
        fft.handler = { data in
            fftData = Array(data[0..<data.count/2])  // Only use first half (nyquist)
            semaphore.signal()
        }
        fft.start()
        
        // Wait for FFT with timeout
        let timeoutResult = semaphore.wait(timeout: .now() + 0.1)
        fft.stop()
        
        return timeoutResult == .success ? fftData : fftProcessor.performFFT(on: samples)
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
    
    private func calculateSpectralFlatness(_ spectrum: [Float]) -> Float {
        let epsilon: Float = 1e-6  // Avoid log(0)
        var logSum: Float = 0
        var sum: Float = 0
        let n = Float(spectrum.count)
        
        for magnitude in spectrum {
            let value = magnitude + epsilon
            logSum += log(value)
            sum += value
        }
        
        let geometricMean = exp(logSum / n)
        let arithmeticMean = sum / n
        
        return geometricMean / arithmeticMean
    }
    
    private func calculateSpectralSpread(_ spectrum: [Float], centroid: Float) -> Float {
        let frequencies = (0..<spectrum.count).map { Float($0) * Float(sampleRate) / Float(fftSize) }
        var numerator: Float = 0
        var denominator: Float = 0
        
        for i in 0..<spectrum.count {
            let diff = frequencies[i] - centroid
            let weight = spectrum[i] * diff * diff
            numerator += weight
            denominator += spectrum[i]
        }
        
        return sqrt(numerator / (denominator + 1e-6))
    }
    
    private func calculateBandEnergies(_ spectrum: [Float]) -> (bass: Float, mid: Float, treble: Float) {
        let bassRange = 0...(fftSize * 200 / Int(sampleRate))  // 0-200Hz
        let midRange = (fftSize * 200 / Int(sampleRate))...(fftSize * 2000 / Int(sampleRate))  // 200Hz-2kHz
        let trebleRange = (fftSize * 2000 / Int(sampleRate))..<spectrum.count  // 2kHz+
        
        var bassEnergy: Float = 0
        var midEnergy: Float = 0
        var trebleEnergy: Float = 0
        
        for i in 0..<spectrum.count {
            let energy = spectrum[i] * spectrum[i]
            if bassRange.contains(i) {
                bassEnergy += energy
            } else if midRange.contains(i) {
                midEnergy += energy
            } else if trebleRange.contains(i) {
                trebleEnergy += energy
            }
        }
        
        // Normalize
        let total = bassEnergy + midEnergy + trebleEnergy + 1e-6
        return (bassEnergy/total, midEnergy/total, trebleEnergy/total)
    }
    
    private func calculateMFCC(_ spectrum: [Float]) -> [Float] {
        // Use AudioKit's filterbank and DCT for proper MFCC calculation
        let numCoefficients = 13
        let numFilters = 26
        let minFreq: Float = 20
        let maxFreq: Float = Float(sampleRate) / 2
        
        // Create mel filterbank
        let melFilters = createMelFilterbank(numFilters: numFilters, fftSize: fftSize, 
                                           sampleRate: Float(sampleRate),
                                           minFreq: minFreq, maxFreq: maxFreq)
        
        // Apply filterbank
        var filteredEnergies = [Float](repeating: 0, count: numFilters)
        for i in 0..<numFilters {
            var sum: Float = 0
            for j in 0..<spectrum.count {
                sum += spectrum[j] * melFilters[i][j]
            }
            filteredEnergies[i] = log(sum + 1e-6)
        }
        
        // Apply DCT
        var mfcc = [Float](repeating: 0, count: numCoefficients)
        for i in 0..<numCoefficients {
            var sum: Float = 0
            for j in 0..<numFilters {
                sum += filteredEnergies[j] * cos(Float.pi * Float(i) * (Float(j) + 0.5) / Float(numFilters))
            }
            mfcc[i] = sum
        }
        
        return mfcc
    }
    
    private func createMelFilterbank(numFilters: Int, fftSize: Int, sampleRate: Float, 
                                   minFreq: Float, maxFreq: Float) -> [[Float]] {
        func freqToMel(_ freq: Float) -> Float {
            return 2595 * log10(1 + freq / 700)
        }
        
        func melToFreq(_ mel: Float) -> Float {
            return 700 * (pow(10, mel / 2595) - 1)
        }
        
        let minMel = freqToMel(minFreq)
        let maxMel = freqToMel(maxFreq)
        let melPoints = (0...numFilters+1).map { i in
            melToFreq(minMel + Float(i) * (maxMel - minMel) / Float(numFilters + 1))
        }
        
        var filterbank = [[Float]](repeating: [Float](repeating: 0, count: fftSize/2),
                                 count: numFilters)
        
        for i in 0..<numFilters {
            for j in 0..<fftSize/2 {
                let freq = Float(j) * sampleRate / Float(fftSize)
                if freq >= melPoints[i] && freq < melPoints[i+1] {
                    filterbank[i][j] = (freq - melPoints[i]) / (melPoints[i+1] - melPoints[i])
                } else if freq >= melPoints[i+1] && freq < melPoints[i+2] {
                    filterbank[i][j] = (melPoints[i+2] - freq) / (melPoints[i+2] - melPoints[i+1])
                }
            }
        }
        
        return filterbank
    }
    
    deinit {
        pitchTap?.stop()
        fftTap?.stop()
        amplitudeTap?.stop()
        engine.stop()
    }
}
