import Foundation
import Accelerate
import AVFoundation

/// Utility class for performing FFT analysis on audio data
class FFTProcessor {
    // FFT configuration
    private let fftSetup: vDSP_DFT_Setup
    private let bufferSize: Int
    private let log2n: vDSP_Length
    private let sampleRate: Float
    private let nyquistFrequency: Float
    
    // Frequency bands for analysis
    private let bassRange: ClosedRange<Float> = 20...250
    private let midRange: ClosedRange<Float> = 250...2000
    private let trebleRange: ClosedRange<Float> = 2000...8000
    
    // Working buffers
    private var window: [Float]
    private var fftInput: [Float]
    private var fftOutput: DSPSplitComplex
    private var magnitudes: [Float]
    private var phases: [Float]
    private var frequencies: [Float]
    
    // Analysis state
    private var lastMagnitudes: [Float]?
    private var timeLastBeat: Float = 0
    private var beatHistory: [Float] = []
    
    init(bufferSize: Int, sampleRate: Float) {
        self.bufferSize = bufferSize
        self.sampleRate = sampleRate
        self.nyquistFrequency = sampleRate / 2.0
        self.log2n = vDSP_Length(log2(Float(bufferSize)))
        
        // Initialize working buffers
        self.window = [Float](repeating: 0, count: bufferSize)
        self.fftInput = [Float](repeating: 0, count: bufferSize)
        self.magnitudes = [Float](repeating: 0, count: bufferSize / 2)
        self.phases = [Float](repeating: 0, count: bufferSize / 2)
        self.frequencies = [Float](repeating: 0, count: bufferSize / 2)
        
        // Initialize split complex buffer for FFT output
        let realp = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize / 2)
        let imagp = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize / 2)
        self.fftOutput = DSPSplitComplex(realp: realp, imagp: imagp)
        
        // Create FFT setup
        guard let setup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(bufferSize),
            vDSP_DFT_Direction.FORWARD
        ) else {
            fatalError("Failed to create FFT setup")
        }
        self.fftSetup = setup
        
        // Initialize window function
        createHannWindow()
        initializeFrequencyArray()
    }
    
    deinit {
        // Clean up allocated memory
        fftOutput.realp.deallocate()
        fftOutput.imagp.deallocate()
        vDSP_DFT_DestroySetup(fftSetup)
    }
    
    /// Process audio buffer and extract spectral features
    func processBuffer(_ buffer: AVAudioPCMBuffer) -> SpectralFeatures? {
        guard let channelData = buffer.floatChannelData,
              buffer.frameLength == bufferSize else { return nil }
        
        // Apply window function to input data
        vDSP_vmul(channelData[0], 1, window, 1, &fftInput, 1, vDSP_Length(bufferSize))
        
        // Perform forward FFT
        fftInput.withUnsafeBytes { ptr in
            let typePtr = ptr.bindMemory(to: DSPComplex.self)
            vDSP_ctoz(typePtr.baseAddress!, 2, &fftOutput, 1, vDSP_Length(bufferSize / 2))
        }
        vDSP_fft_zrip(fftSetup, &fftOutput, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitude spectrum
        vDSP_zvmags(&fftOutput, 1, &magnitudes, 1, vDSP_Length(bufferSize / 2))
        
        // Calculate phase spectrum
        vDSP_zvphas(&fftOutput, 1, &phases, 1, vDSP_Length(bufferSize / 2))
        
        // Extract spectral features
        let spectralCentroid = calculateSpectralCentroid()
        let spectralRolloff = calculateSpectralRolloff()
        let spectralFlux = calculateSpectralFlux()
        let spectralContrast = calculateSpectralContrast()
        
        // Calculate energy in different frequency bands
        let bassEnergy = calculateBandEnergy(range: bassRange)
        let midEnergy = calculateBandEnergy(range: midRange)
        let trebleEnergy = calculateBandEnergy(range: trebleRange)
        
        // Estimate tempo and beat strength
        let (estimatedTempo, beatStrength) = estimateTempoAndBeatStrength()
        
        // Store current magnitudes for next flux calculation
        lastMagnitudes = magnitudes
        
        return SpectralFeatures(
            spectralCentroid: spectralCentroid,
            spectralRolloff: spectralRolloff,
            spectralFlux: spectralFlux,
            spectralContrast: spectralContrast,
            zeroCrossingRate: calculateZeroCrossingRate(buffer),
            dynamicRange: calculateDynamicRange(),
            bassEnergy: bassEnergy,
            midEnergy: midEnergy,
            trebleEnergy: trebleEnergy,
            estimatedTempo: estimatedTempo,
            beatStrength: beatStrength
        )
    }
    
    // MARK: - Feature Calculation Methods
    
    private func calculateSpectralCentroid() -> Float {
        var weightedSum: Float = 0
        var sum: Float = 0
        
        for i in 0..<bufferSize/2 {
            weightedSum += frequencies[i] * magnitudes[i]
            sum += magnitudes[i]
        }
        
        return sum > 0 ? weightedSum / sum : 0
    }
    
    private func calculateSpectralRolloff(percentage: Float = 0.85) -> Float {
        let totalEnergy = magnitudes.reduce(0, +)
        let threshold = totalEnergy * percentage
        var accumulator: Float = 0
        
        for i in 0..<bufferSize/2 {
            accumulator += magnitudes[i]
            if accumulator >= threshold {
                return frequencies[i]
            }
        }
        return nyquistFrequency
    }
    
    private func calculateSpectralFlux() -> Float {
        guard let lastMags = lastMagnitudes else { return 0 }
        
        var flux: Float = 0
        for i in 0..<bufferSize/2 {
            let diff = magnitudes[i] - lastMags[i]
            flux += diff * diff
        }
        return sqrt(flux)
    }
    
    private func calculateSpectralContrast() -> Float {
        let valleyBins = 5
        let peakBins = 5
        
        let sortedMagnitudes = magnitudes.sorted()
        let valleys = sortedMagnitudes[..<valleyBins].reduce(0, +) / Float(valleyBins)
        let peaks = sortedMagnitudes[(bufferSize/2 - peakBins)...].reduce(0, +) / Float(peakBins)
        
        return peaks - valleys
    }
    
    private func calculateZeroCrossingRate(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        
        var crossings: Int = 0
        for i in 1..<bufferSize {
            if data[i-1] * data[i] < 0 {
                crossings += 1
            }
        }
        
        return Float(crossings) / Float(bufferSize)
    }
    
    private func calculateDynamicRange() -> Float {
        let sortedMagnitudes = magnitudes.sorted()
        let p90 = sortedMagnitudes[Int(Float(bufferSize/2) * 0.9)]
        let p10 = sortedMagnitudes[Int(Float(bufferSize/2) * 0.1)]
        return p90 - p10
    }
    
    private func calculateBandEnergy(range: ClosedRange<Float>) -> Float {
        var energy: Float = 0
        var count: Int = 0
        
        for i in 0..<bufferSize/2 {
            if range.contains(frequencies[i]) {
                energy += magnitudes[i]
                count += 1
            }
        }
        
        return count > 0 ? energy / Float(count) : 0
    }
    
    private func estimateTempoAndBeatStrength() -> (tempo: Float, strength: Float) {
        let energyChange = calculateSpectralFlux()
        let currentTime = Float(Date().timeIntervalSince1970)
        
        if energyChange > 0.5 && (currentTime - timeLastBeat) > 0.2 {  // 200ms minimum between beats
            let beatInterval = currentTime - timeLastBeat
            timeLastBeat = currentTime
            
            beatHistory.append(beatInterval)
            if beatHistory.count > 8 { beatHistory.removeFirst() }
        }
        
        // Calculate tempo from beat history
        if beatHistory.isEmpty { return (0, 0) }
        
        let averageInterval = beatHistory.reduce(0, +) / Float(beatHistory.count)
        let tempo = 60.0 / averageInterval  // Convert to BPM
        
        // Calculate beat strength based on consistency
        let variance = beatHistory.map { pow($0 - averageInterval, 2) }.reduce(0, +) / Float(beatHistory.count)
        let beatStrength = 1.0 / (1.0 + variance)  // Normalize to 0-1 range
        
        return (tempo, beatStrength)
    }
    
    // MARK: - Initialization Helpers
    
    private func createHannWindow() {
        vDSP_hann_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))
    }
    
    private func initializeFrequencyArray() {
        for i in 0..<bufferSize/2 {
            frequencies[i] = Float(i) * sampleRate / Float(bufferSize)
        }
    }
}

/// Structure containing extracted spectral features
struct SpectralFeatures {
    let spectralCentroid: Float      // Weighted mean of frequencies
    let spectralRolloff: Float       // Frequency below which 85% of energy exists
    let spectralFlux: Float          // Rate of change of spectrum
    let spectralContrast: Float      // Difference between peaks and valleys
    let zeroCrossingRate: Float      // Rate of signal sign-changes
    let dynamicRange: Float          // Difference between loudest and quietest parts
    let bassEnergy: Float           // Energy in low frequencies
    let midEnergy: Float            // Energy in mid frequencies
    let trebleEnergy: Float         // Energy in high frequencies
    let estimatedTempo: Float       // Estimated BPM
    let beatStrength: Float         // Confidence in beat detection (0-1)
}
