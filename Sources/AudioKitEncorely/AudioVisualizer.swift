import Foundation
import SwiftUI
import Accelerate
import Combine

// MARK: - Audio Visualizer
@MainActor
public class AudioVisualizer: ObservableObject {
    @Published public var waveformData: [Float] = []
    @Published public var spectrumData: [Float] = []
    @Published public var rmsLevel: Float = 0.0
    @Published public var peakLevel: Float = 0.0
    
    private var updateTimer: Timer?
    private var sampleBuffer: [Float] = []
    private let bufferSize = 1024
    private let fftSize = 512
    
    public init() {
        setupInitialData()
    }
    
    deinit {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    public func startVisualization() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateVisualizationData()
            }
        }
    }
    
    public func stopVisualization() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    public func processAudioBuffer(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        
        // Update sample buffer
        sampleBuffer.append(contentsOf: samples)
        
        // Keep buffer size manageable
        if sampleBuffer.count > bufferSize * 2 {
            sampleBuffer = Array(sampleBuffer.suffix(bufferSize))
        }
        
        // Update real-time metrics
        rmsLevel = DSP.rms(samples)
        peakLevel = samples.map(abs).max() ?? 0.0
        
        // Update waveform data
        updateWaveformData(samples)
        
        // Update spectrum data
        updateSpectrumData(samples)
    }
    
    private func setupInitialData() {
        // Initialize with empty data
        waveformData = Array(repeating: 0.0, count: 128)
        spectrumData = Array(repeating: 0.0, count: fftSize / 2)
    }
    
    private func updateVisualizationData() {
        // Generate realistic demo data when no real audio
        if sampleBuffer.isEmpty {
            generateDemoData()
        }
    }
    
    private func updateWaveformData(_ samples: [Float]) {
        let downsampleFactor = max(1, samples.count / 128)
        var downsampled: [Float] = []
        
        for i in stride(from: 0, to: samples.count, by: downsampleFactor) {
            if i < samples.count {
                downsampled.append(samples[i])
            }
        }
        
        // Pad or truncate to exactly 128 samples
        if downsampled.count < 128 {
            downsampled.append(contentsOf: Array(repeating: 0.0, count: 128 - downsampled.count))
        } else if downsampled.count > 128 {
            downsampled = Array(downsampled.prefix(128))
        }
        
        waveformData = downsampled
    }
    
    private func updateSpectrumData(_ samples: [Float]) {
        guard samples.count >= fftSize else { return }
        
        let fftSamples = Array(samples.prefix(fftSize))
        let spectrum = performFFT(fftSamples)
        
        // Apply logarithmic scaling for better visualization
        spectrumData = spectrum.map { amplitude in
            let db = 20 * log10(max(amplitude, 1e-10))
            return max(0, (db + 100) / 100) // Normalize to 0-1
        }
    }
    
    private func performFFT(_ samples: [Float]) -> [Float] {
        var realParts = samples
        var imaginaryParts = Array(repeating: Float(0.0), count: fftSize)
        
        // Create FFT setup
        guard let fftSetup = vDSP_create_fftsetup(
            vDSP_Length(log2(Float(fftSize))),
            FFTRadix(kFFTRadix2)
        ) else {
            return Array(repeating: 0.0, count: fftSize / 2)
        }
        
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        // Use withUnsafeMutableBufferPointer for safe memory access
        return realParts.withUnsafeMutableBufferPointer { realPtr in
            return imaginaryParts.withUnsafeMutableBufferPointer { imagPtr in
                guard let realBase = realPtr.baseAddress,
                      let imagBase = imagPtr.baseAddress else {
                    return Array(repeating: 0.0, count: fftSize / 2)
                }
                
                var splitComplex = DSPSplitComplex(
                    realp: realBase,
                    imagp: imagBase
                )
                
                // Perform forward FFT
                vDSP_fft_zip(
                    fftSetup,
                    &splitComplex,
                    1,
                    vDSP_Length(log2(Float(fftSize))),
                    FFTDirection(kFFTDirection_Forward)
                )
                
                // Calculate magnitudes
                var magnitudes = Array(repeating: Float(0.0), count: fftSize / 2)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
                
                // Take square root to get actual magnitudes  
                var sqrtMagnitudes = Array(repeating: Float(0.0), count: fftSize / 2)
                vvsqrtf(&sqrtMagnitudes, magnitudes, [Int32(fftSize / 2)])
                
                return sqrtMagnitudes
            }
        }
    }
    
    private func generateDemoData() {
        let time = Date().timeIntervalSinceReferenceDate
        
        // Generate demo waveform
        waveformData = (0..<128).map { i in
            let t = Float(time) + Float(i) * 0.1
            return sin(t * 2) * 0.5 + sin(t * 5) * 0.3 + sin(t * 10) * 0.1
        }
        
        // Generate demo spectrum
        spectrumData = (0..<(fftSize / 2)).map { i in
            let frequency = Float(i) / Float(fftSize / 2)
            let amplitude = exp(-frequency * 3) * (0.5 + 0.5 * sin(Float(time) * 2 + frequency * 10))
            return amplitude * Float.random(in: 0.8...1.2)
        }
        
        // Update levels
        rmsLevel = Float.random(in: 0.1...0.8)
        peakLevel = min(1.0, rmsLevel * Float.random(in: 1.1...1.5))
    }
}


// MARK: - Advanced DSP Extensions
public extension DSP {
    /// Apply a simple low-pass filter to audio samples
    static func lowPassFilter(_ samples: [Float], cutoffFrequency: Float, sampleRate: Float) -> [Float] {
        guard !samples.isEmpty else { return [] }
        
        let rc = 1.0 / (cutoffFrequency * 2 * Float.pi)
        let dt = 1.0 / sampleRate
        let alpha = dt / (rc + dt)
        
        var filtered = Array(repeating: Float(0), count: samples.count)
        filtered[0] = samples[0] * alpha
        
        for i in 1..<samples.count {
            filtered[i] = filtered[i-1] + alpha * (samples[i] - filtered[i-1])
        }
        
        return filtered
    }
    
    /// Calculate the spectral centroid of audio samples
    static func spectralCentroid(_ samples: [Float], sampleRate: Float) -> Float {
        guard samples.count >= 512 else { return 0 }
        
        let fftSize = 512
        let fftSamples = Array(samples.prefix(fftSize))
        
        // Perform FFT (simplified - in real implementation you'd use vDSP)
        let spectrum = performSimpleFFT(fftSamples)
        
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        
        for (i, magnitude) in spectrum.enumerated() {
            let frequency = Float(i) * sampleRate / Float(fftSize)
            weightedSum += frequency * magnitude
            magnitudeSum += magnitude
        }
        
        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0
    }
    
    private static func performSimpleFFT(_ samples: [Float]) -> [Float] {
        // Simplified FFT implementation for demo purposes
        // In production, use vDSP_fft_zip
        let n = samples.count
        return (0..<(n/2)).map { k in
            var real: Float = 0
            var imag: Float = 0
            
            for i in 0..<n {
                let angle = -2 * Float.pi * Float(k) * Float(i) / Float(n)
                real += samples[i] * cos(angle)
                imag += samples[i] * sin(angle)
            }
            
            return sqrt(real * real + imag * imag)
        }
    }
}