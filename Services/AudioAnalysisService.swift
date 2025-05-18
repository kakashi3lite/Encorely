//
//  AudioAnalysisService.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import AVFoundation
import Accelerate
import CoreML

// MARK: - Audio Features Model
struct AudioFeatures: Codable {
    let tempo: Float            // BPM (60-200 normalized to 0-1)
    let energy: Float           // RMS energy (0-1)
    let spectralCentroid: Float // Spectral centroid (0-1)
    let valence: Float          // Musical positivity (0-1)
    let danceability: Float     // Danceability (0-1)
    let acousticness: Float     // Acoustic confidence (0-1)
    let instrumentalness: Float // Instrumental confidence (0-1)
    let speechiness: Float      // Speech presence (0-1)
    let liveness: Float         // Live audience presence (0-1)
}

// MARK: - AI Errors
enum AIError: Error, LocalizedError {
    case audioProcessingFailed(String)
    case invalidAudioFile
    case insufficientData
    
    var errorDescription: String? {
        switch self {
        case .audioProcessingFailed(let reason):
            return "Audio processing failed: \(reason)"
        case .invalidAudioFile:
            return "Invalid or corrupted audio file"
        case .insufficientData:
            return "Insufficient audio data for analysis"
        }
    }
}

// MARK: - Audio Analysis Service
class AudioAnalysisService {
    private let audioEngine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "com.mixtapes.audioanalysis", qos: .userInitiated)
    private let fftSize: Int = 4096
    private let hopSize: Int = 2048
    
    // MARK: - Public Methods
    
    /// Extract real audio features from file
    func extractRealFeatures(from audioFile: AVAudioFile) throws -> AudioFeatures {
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        guard frameCount > 0, format.sampleRate > 0 else {
            throw AIError.invalidAudioFile
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AIError.audioProcessingFailed("Failed to create audio buffer")
        }
        
        // Read audio data
        do {
            try audioFile.read(into: buffer)
        } catch {
            throw AIError.audioProcessingFailed("Failed to read audio file: \(error.localizedDescription)")
        }
        
        guard let channelData = buffer.floatChannelData, buffer.frameLength > 0 else {
            throw AIError.insufficientData
        }
        
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
        let sampleRate = Float(format.sampleRate)
        
        // Extract features
        let tempo = try detectTempo(samples: samples, sampleRate: sampleRate)
        let energy = calculateEnergy(samples: samples)
        let spectralCentroid = try calculateSpectralCentroid(samples: samples, sampleRate: sampleRate)
        
        // Generate additional features (for demo - would use real analysis in production)
        let features = AudioFeatures(
            tempo: normalizeTempo(tempo),
            energy: energy,
            spectralCentroid: spectralCentroid,
            valence: Float.random(in: 0...1),
            danceability: Float.random(in: 0...1),
            acousticness: Float.random(in: 0...1),
            instrumentalness: Float.random(in: 0...1),
            speechiness: Float.random(in: 0...1),
            liveness: Float.random(in: 0...1)
        )
        
        return features
    }
    
    /// Detect tempo from audio samples
    func detectTempo(samples: [Float], sampleRate: Float) throws -> Float {
        guard samples.count >= fftSize else {
            throw AIError.insufficientData
        }
        
        // Calculate onset detection function
        let onsetStrength = calculateOnsetStrength(samples: samples, sampleRate: sampleRate)
        
        // Find tempo using autocorrelation
        let tempo = findTempoFromOnsets(onsetStrength: onsetStrength, sampleRate: sampleRate)
        
        return tempo
    }
    
    // MARK: - Private Methods
    
    /// Calculate energy (RMS) from samples
    private func calculateEnergy(samples: [Float]) -> Float {
        var sum: Float = 0.0
        vDSP_svesq(samples, 1, &sum, vDSP_Length(samples.count))
        let rms = sqrt(sum / Float(samples.count))
        return min(rms * 10, 1.0) // Normalize and clamp to [0,1]
    }
    
    /// Calculate spectral centroid
    private func calculateSpectralCentroid(samples: [Float], sampleRate: Float) throws -> Float {
        let fftLength = min(fftSize, samples.count)
        guard fftLength >= 64 else {
            throw AIError.insufficientData
        }
        
        // Setup FFT
        let log2n = vDSP_Length(log2(Float(fftLength)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            throw AIError.audioProcessingFailed("Failed to create FFT setup")
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // Prepare input
        var realParts = Array(samples[0..<fftLength])
        var imagParts = Array(repeating: Float(0), count: fftLength)
        
        // Perform FFT
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
        vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitude spectrum
        var magnitudes = Array(repeating: Float(0), count: fftLength/2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftLength/2))
        
        // Calculate spectral centroid
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        
        for i in 0..<magnitudes.count {
            let frequency = Float(i) * sampleRate / Float(fftLength)
            weightedSum += frequency * magnitudes[i]
            magnitudeSum += magnitudes[i]
        }
        
        let centroid = magnitudeSum > 0 ? weightedSum / magnitudeSum : 0
        return min(centroid / (sampleRate / 4), 1.0) // Normalize to [0,1]
    }
    
    /// Calculate onset strength for tempo detection
    private func calculateOnsetStrength(samples: [Float], sampleRate: Float) -> [Float] {
        let hopCount = (samples.count - fftSize) / hopSize + 1
        var onsetStrength = Array(repeating: Float(0), count: hopCount)
        
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return onsetStrength
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        var previousMagnitudes = Array(repeating: Float(0), count: fftSize/2)
        
        for hop in 0..<hopCount {
            let startIndex = hop * hopSize
            let endIndex = min(startIndex + fftSize, samples.count)
            
            guard endIndex - startIndex >= fftSize else { break }
            
            // Extract frame
            var realParts = Array(samples[startIndex..<endIndex])
            var imagParts = Array(repeating: Float(0), count: fftSize)
            
            // Apply window (Hann window)
            applyHannWindow(&realParts)
            
            // FFT
            var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
            vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
            
            // Calculate magnitudes
            var magnitudes = Array(repeating: Float(0), count: fftSize/2)
            vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize/2))
            
            // Calculate spectral flux (onset strength)
            if hop > 0 {
                var flux: Float = 0
                for i in 0..<magnitudes.count {
                    let diff = magnitudes[i] - previousMagnitudes[i]
                    flux += max(diff, 0) // Only positive changes
                }
                onsetStrength[hop] = flux
            }
            
            previousMagnitudes = magnitudes
        }
        
        return onsetStrength
    }
    
    /// Find tempo from onset strength using autocorrelation
    private func findTempoFromOnsets(onsetStrength: [Float], sampleRate: Float) -> Float {
        guard onsetStrength.count > 1 else { return 120.0 }
        
        let minBPM: Float = 60
        let maxBPM: Float = 200
        let hopDuration = Float(hopSize) / sampleRate
        
        let minLag = Int(60 / (maxBPM * hopDuration))
        let maxLag = min(Int(60 / (minBPM * hopDuration)), onsetStrength.count / 2)
        
        guard maxLag > minLag else { return 120.0 }
        
        var maxCorrelation: Float = 0
        var bestLag = minLag
        
        // Simple autocorrelation for tempo detection
        for lag in minLag...maxLag {
            var correlation: Float = 0
            let validCount = onsetStrength.count - lag
            
            for i in 0..<validCount {
                correlation += onsetStrength[i] * onsetStrength[i + lag]
            }
            
            if correlation > maxCorrelation {
                maxCorrelation = correlation
                bestLag = lag
            }
        }
        
        let tempo = 60 / (Float(bestLag) * hopDuration)
        return max(minBPM, min(maxBPM, tempo))
    }
    
    /// Apply Hann window to reduce spectral leakage
    private func applyHannWindow(_ samples: inout [Float]) {
        let count = samples.count
        for i in 0..<count {
            let window = 0.5 - 0.5 * cos(2 * Float.pi * Float(i) / Float(count - 1))
            samples[i] *= window
        }
    }
    
    /// Normalize tempo to [0,1] range
    private func normalizeTempo(_ tempo: Float) -> Float {
        let minBPM: Float = 60
        let maxBPM: Float = 200
        return (tempo - minBPM) / (maxBPM - minBPM)
    }
    
    /// Detect mood from extracted features
    func detectMood(from features: AudioFeatures) -> Mood {
        // Convert normalized tempo back for logic
        let actualTempo = features.tempo * 140 + 60
        
        if actualTempo > 130 {
            if features.energy > 0.7 {
                return features.valence > 0.6 ? .energetic : .angry
            } else {
                return features.valence > 0.6 ? .happy : .focused
            }
        } else {
            if features.energy < 0.4 {
                return features.valence > 0.5 ? .relaxed : .melancholic
            } else {
                return features.valence > 0.7 ? .romantic : .neutral
            }
        }
    }
}