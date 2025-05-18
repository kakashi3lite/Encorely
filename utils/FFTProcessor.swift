//
//  FFTProcessor.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import Accelerate
import AVFoundation

/// Utility class for performing FFT analysis on audio data
class FFTProcessor {
    // FFT setup
    private let fftSetup: vDSP_DFT_Setup
    private let bufferSize: Int
    private let log2n: vDSP_Length
    
    // Working buffers
    private var window: [Float]
    private var fftInput: [Float]
    private var fftOutput: DSPSplitComplex
    private var magnitudes: [Float]
    
    // Analysis parameters
    private let sampleRate: Float
    private let nyquistFrequency: Float
    
    init(bufferSize: Int, sampleRate: Float) {
        self.bufferSize = bufferSize
        self.sampleRate = sampleRate
        self.nyquistFrequency = sampleRate / 2.0
        self.log2n = vDSP_Length(log2(Float(bufferSize)))
        
        // Create FFT setup
        guard let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(bufferSize), .FORWARD) else {
            fatalError("Failed to create FFT setup")
        }
        self.fftSetup = setup
        
        // Initialize working buffers
        self.window = Array(repeating: 0.0, count: bufferSize)
        self.fftInput = Array(repeating: 0.0, count: bufferSize)
        self.magnitudes = Array(repeating: 0.0, count: bufferSize / 2)
        
        // Allocate split complex buffer
        let halfSize = bufferSize / 2
        self.fftOutput = DSPSplitComplex(
            realp: UnsafeMutablePointer<Float>.allocate(capacity: halfSize),
            imagp: UnsafeMutablePointer<Float>.allocate(capacity: halfSize)
        )
        
        // Create Hann window
        createHannWindow()
    }
    
    deinit {
        // Clean up FFT setup and buffers
        vDSP_DFT_DestroySetup(fftSetup)
        fftOutput.realp.deallocate()
        fftOutput.imagp.deallocate()
    }
    
    /// Create Hann window for better frequency resolution
    private func createHannWindow() {
        vDSP_hann_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))
    }
    
    /// Process audio buffer and extract spectral features
    func processBuffer(_ audioBuffer: AVAudioPCMBuffer) -> SpectralFeatures? {
        guard let channelData = audioBuffer.floatChannelData,
              audioBuffer.frameLength == bufferSize else { return nil }
        
        // Copy and window the input data
        let inputData = channelData[0]
        vDSP_vmul(inputData, 1, window, 1, &fftInput, 1, vDSP_Length(bufferSize))
        
        // Perform FFT
        vDSP_DFT_Execute(fftSetup, fftInput, fftOutput)
        
        // Calculate magnitudes
        let halfSize = bufferSize / 2
        vDSP_zvmags(&fftOutput, 1, &magnitudes, 1, vDSP_Length(halfSize))
        
        // Convert to dB and normalize
        var logMagnitudes = Array(repeating: Float(0.0), count: halfSize)
        vDSP_vdbcon(magnitudes, 1, &logMagnitudes, 1, vDSP_Length(halfSize))
        
        // Extract features from the spectrum
        return extractSpectralFeatures(from: logMagnitudes)
    }
    
    /// Extract meaningful features from FFT magnitudes
    private func extractSpectralFeatures(from spectrum: [Float]) -> SpectralFeatures {
        let binWidth = nyquistFrequency / Float(spectrum.count)
        
        // Calculate spectral centroid (brightness)
        let spectralCentroid = calculateSpectralCentroid(spectrum: spectrum, binWidth: binWidth)
        
        // Calculate spectral rolloff
        let spectralRolloff = calculateSpectralRolloff(spectrum: spectrum, binWidth: binWidth)
        
        // Calculate spectral contrast
        let spectralContrast = calculateSpectralContrast(spectrum: spectrum)
        
        // Calculate zero crossing rate
        let zeroCrossingRate = calculateZeroCrossingRate()
        
        // Estimate tempo
        let estimatedTempo = estimateTempo(from: spectrum)
        
        // Calculate energy distribution
        let energyDistribution = calculateEnergyDistribution(spectrum: spectrum)
        
        return SpectralFeatures(
            spectralCentroid: spectralCentroid,
            spectralRolloff: spectralRolloff,
            spectralContrast: spectralContrast,
            zeroCrossingRate: zeroCrossingRate,
            estimatedTempo: estimatedTempo,
            bassEnergy: energyDistribution.bass,
            midEnergy: energyDistribution.mid,
            trebleEnergy: energyDistribution.treble,
            totalEnergy: energyDistribution.total
        )
    }
    
    /// Calculate spectral centroid (brightness indicator)
    private func calculateSpectralCentroid(spectrum: [Float], binWidth: Float) -> Float {
        var weightedSum: Float = 0.0
        var magnitudeSum: Float = 0.0
        
        for (bin, magnitude) in spectrum.enumerated() {
            let frequency = Float(bin) * binWidth
            let linearMagnitude = pow(10, magnitude / 20.0)
            weightedSum += frequency * linearMagnitude
            magnitudeSum += linearMagnitude
        }
        
        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0.0
    }
    
    /// Calculate spectral rolloff
    private func calculateSpectralRolloff(spectrum: [Float], binWidth: Float) -> Float {
        let linearSpectrum = spectrum.map { pow(10, $0 / 20.0) }
        let totalEnergy = linearSpectrum.reduce(0, +)
        let threshold = totalEnergy * 0.85
        
        var cumulativeEnergy: Float = 0.0
        for (bin, magnitude) in linearSpectrum.enumerated() {
            cumulativeEnergy += magnitude
            if cumulativeEnergy >= threshold {
                return Float(bin) * binWidth
            }
        }
        
        return nyquistFrequency
    }
    
    /// Calculate spectral contrast
    private func calculateSpectralContrast(spectrum: [Float]) -> Float {
        let octaveBands = getOctaveBands()
        var contrastSum: Float = 0.0
        
        for band in octaveBands {
            let bandSpectrum = Array(spectrum[band.start..<band.end])
            let peak = bandSpectrum.max() ?? -80.0
            let valley = bandSpectrum.min() ?? -80.0
            contrastSum += peak - valley
        }
        
        return contrastSum / Float(octaveBands.count)
    }
    
    /// Get octave band ranges
    private func getOctaveBands() -> [(start: Int, end: Int)] {
        let binWidth = nyquistFrequency / Float(magnitudes.count)
        let octaveFreqs: [Float] = [250, 500, 1000, 2000, 4000, 8000]
        var bands: [(start: Int, end: Int)] = []
        
        for i in 0..<(octaveFreqs.count - 1) {
            let startBin = Int(octaveFreqs[i] / binWidth)
            let endBin = Int(octaveFreqs[i + 1] / binWidth)
            if startBin < magnitudes.count && endBin <= magnitudes.count {
                bands.append((start: startBin, end: endBin))
            }
        }
        
        return bands
    }
    
    /// Calculate zero crossing rate
    private func calculateZeroCrossingRate() -> Float {
        var crossings = 0
        for i in 1..<fftInput.count {
            if (fftInput[i] >= 0) != (fftInput[i-1] >= 0) {
                crossings += 1
            }
        }
        return Float(crossings) / Float(fftInput.count - 1)
    }
    
    /// Estimate tempo from spectral flux
    private func estimateTempo(from spectrum: [Float]) -> Float {
        let rhythmBandStart = Int(60.0 / (nyquistFrequency / Float(spectrum.count)))
        let rhythmBandEnd = Int(200.0 / (nyquistFrequency / Float(spectrum.count)))
        
        let startIndex = max(0, rhythmBandStart)
        let endIndex = min(spectrum.count, rhythmBandEnd)
        
        if startIndex < endIndex {
            let rhythmEnergy = spectrum[startIndex..<endIndex].reduce(0, +)
            let normalizedEnergy = (rhythmEnergy + 80) / 80
            return 60 + (normalizedEnergy * 120)
        }
        
        return 120.0
    }
    
    /// Calculate energy distribution across frequency bands
    private func calculateEnergyDistribution(spectrum: [Float]) -> (bass: Float, mid: Float, treble: Float, total: Float) {
        let binWidth = nyquistFrequency / Float(spectrum.count)
        
        let bassEnd = Int(250.0 / binWidth)
        let midEnd = Int(4000.0 / binWidth)
        let trebleEnd = spectrum.count
        
        let bassEnergy = spectrum[0..<min(bassEnd, spectrum.count)]
            .map { pow(10, $0 / 10) }.reduce(0, +)
        
        let midStart = min(bassEnd, spectrum.count)
        let midEnergy = spectrum[midStart..<min(midEnd, spectrum.count)]
            .map { pow(10, $0 / 10) }.reduce(0, +)
        
        let trebleStart = min(midEnd, spectrum.count)
        let trebleEnergy = spectrum[trebleStart..<trebleEnd]
            .map { pow(10, $0 / 10) }.reduce(0, +)
        
        let totalEnergy = bassEnergy + midEnergy + trebleEnergy
        
        return (
            bass: totalEnergy > 0 ? bassEnergy / totalEnergy : 0,
            mid: totalEnergy > 0 ? midEnergy / totalEnergy : 0,
            treble: totalEnergy > 0 ? trebleEnergy / totalEnergy : 0,
            total: totalEnergy
        )
    }
}

/// Spectral features extracted from FFT analysis
struct SpectralFeatures {
    let spectralCentroid: Float
    let spectralRolloff: Float
    let spectralContrast: Float
    let zeroCrossingRate: Float
    let estimatedTempo: Float
    let bassEnergy: Float
    let midEnergy: Float
    let trebleEnergy: Float
    let totalEnergy: Float
}
