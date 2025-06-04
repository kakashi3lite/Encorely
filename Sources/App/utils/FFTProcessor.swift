import Foundation
import Accelerate
import AVFoundation

/// Enhanced FFT processor with comprehensive spectral feature extraction
class FFTProcessor {
    // MARK: - Properties
    
    private let fftSetup: vDSP_DFT_Setup?
    private let maxFrameSize: Int
    private let sampleRate: Float
    private var window: [Float]
    private let magnitudeNormalizationFactor: Float
    private var tempBuffer: [Float]
    
    // Previous magnitudes for spectral flux calculation
    private var previousMagnitudes: [Float]?
    
    // MARK: - Frequency band thresholds in Hz
    private let bassUpperLimit: Float = 250.0
    private let midUpperLimit: Float = 4000.0
    // Everything above midUpperLimit is treble
    
    // MARK: - Initialization
    
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
    
    // MARK: - Main Processing
    
    /// Processes audio buffer and extracts spectral features
    /// - Parameter buffer: Audio buffer to analyze
    /// - Returns: Extracted spectral features or nil if processing fails
    func processBuffer(_ buffer: AVAudioPCMBuffer) -> SpectralFeatures? {
        guard let channelData = buffer.floatChannelData?[0],
              buffer.frameLength > 0 else {
            return nil
        }
        
        // Get magnitude spectrum
        guard let magnitudes = try? getMagnitudeSpectrum(from: channelData, frameCount: Int(buffer.frameLength)) else {
            return nil
        }
        
        // Extract spectral features
        let features = extractSpectralFeatures(from: magnitudes)
        
        // Store magnitudes for next flux calculation
        previousMagnitudes = magnitudes
        
        return features
    }
    
    /// Advanced spectral analysis with multiple techniques
    /// - Parameter buffer: Audio buffer to analyze
    /// - Returns: Audio features extracted from spectral analysis
    func analyzeSpectralFeatures(_ buffer: AVAudioPCMBuffer) -> SpectralFeatures? {
        guard let channelData = buffer.floatChannelData?[0],
              buffer.frameLength > 0 else {
            return nil
        }
        
        // Prepare the spectral features structure
        var spectralFeatures = SpectralFeatures()
        
        // Get magnitude spectrum
        guard let magnitudes = try? getMagnitudeSpectrum(from: channelData, frameCount: Int(buffer.frameLength)) else {
            return nil
        }
        
        // Calculate spectral centroid
        if let centroid = calculateSpectralCentroid(magnitudes: magnitudes) {
            spectralFeatures.centroid = centroid
            
            // Convert centroid to perceived brightness (normalize to 0-1)
            // Typical centroid range for music is between 500-5000 Hz
            let normalizedCentroid = max(0, min(1, (centroid - 500) / 4500))
            spectralFeatures.brightness = normalizedCentroid
        }
        
        // Calculate spectral flux (if we have previous magnitudes)
        if let prevMags = previousMagnitudes {
            let flux = calculateSpectralFlux(current: magnitudes, previous: prevMags)
            spectralFeatures.flux = flux
        }
        
        // Calculate spectral spread
        if let spread = calculateSpectralSpread(magnitudes: magnitudes, centroid: spectralFeatures.centroid ?? 0) {
            spectralFeatures.spread = spread
        }
        
        // Calculate spectral rolloff
        if let rolloff = calculateSpectralRolloff(magnitudes: magnitudes) {
            spectralFeatures.rolloff = rolloff
        }
        
        // Calculate spectral flatness
        if let flatness = calculateSpectralFlatness(magnitudes: magnitudes) {
            spectralFeatures.flatness = flatness
        }
        
        // Calculate crest factor
        if let crest = calculateSpectralCrest(magnitudes: magnitudes) {
            spectralFeatures.crest = crest
        }
        
        // Calculate spectral irregularity
        if let irregularity = calculateSpectralIrregularity(magnitudes: magnitudes) {
            spectralFeatures.irregularity = irregularity
        }
        
        // Calculate spectral roughness (related to dissonance)
        if let roughness = calculateSpectralRoughness(magnitudes: magnitudes) {
            spectralFeatures.roughness = roughness
        }
        
        // Calculate higher moments: skewness and kurtosis
        if let skewness = calculateSpectralSkewness(magnitudes: magnitudes, centroid: spectralFeatures.centroid ?? 0, spread: spectralFeatures.spread ?? 1) {
            spectralFeatures.skewness = skewness
        }
        
        if let kurtosis = calculateSpectralKurtosis(magnitudes: magnitudes, centroid: spectralFeatures.centroid ?? 0, spread: spectralFeatures.spread ?? 1) {
            spectralFeatures.kurtosis = kurtosis
        }
        
        // Store current magnitudes for flux calculation in next frame
        previousMagnitudes = magnitudes
        
        return spectralFeatures
    }
    
    // MARK: - FFT Processing
    
    /// Performs FFT and returns magnitude spectrum
    /// - Parameters:
    ///   - buffer: Audio sample buffer
    ///   - frameCount: Number of frames to process
    /// - Returns: Magnitude spectrum
    /// - Throws: FFTError if processing fails
    func getMagnitudeSpectrum(from buffer: UnsafePointer<Float>, frameCount: Int) throws -> [Float] {
        let frameSize = determineFrameSize(frameCount)
        var realPart = [Float](repeating: 0, count: maxFrameSize)
        var imagPart = [Float](repeating: 0, count: maxFrameSize)
        
        // Copy samples and apply window
        buffer.withMemoryRebound(to: Float.self, capacity: frameCount) { ptr in
            realPart.withUnsafeMutableBufferPointer { realPtr in
                realPtr.baseAddress?.initialize(from: ptr, count: min(frameCount, maxFrameSize))
            }
        }
        
        // Apply Hanning window
        vDSP_vmul(realPart, 1, window, 1, &realPart, 1, vDSP_Length(frameSize))
        
        // Perform real-to-complex FFT
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        guard let fftSetup = fftSetup else {
            throw AudioAnalysisError.bufferProcessingFailed("FFT setup not initialized")
        }
        
        vDSP_DFT_Execute(fftSetup, &realPart, &imagPart, &splitComplex.realp, &splitComplex.imagp)
        
        // Calculate magnitude spectrum
        let usefulBins = frameSize / 2  // Only use positive frequencies
        var magnitudes = [Float](repeating: 0, count: usefulBins)
        
        // Compute magnitude: sqrt(real^2 + imag^2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(usefulBins))
        vDSP_vsqrt(magnitudes, 1, &magnitudes, 1, vDSP_Length(usefulBins))
        vDSP_vsmul(magnitudes, 1, &magnitudeNormalizationFactor, &magnitudes, 1, vDSP_Length(usefulBins))
        
        return magnitudes
    }
    
    /// Determines appropriate frame size to process
    private func determineFrameSize(_ frameCount: Int) -> Int {
        var size = 1
        while size <= maxFrameSize && size < frameCount {
            size *= 2
        }
        
        // If we've exceeded the max frame size, go back one step
        if size > maxFrameSize {
            size = maxFrameSize
        }
        
        return size
    }
    
    // MARK: - Spectral Feature Extraction
    
    /// Extracts comprehensive spectral features from magnitude spectrum
    /// - Parameter magnitudes: Magnitude spectrum from FFT
    /// - Returns: Extracted spectral features 
    private func extractSpectralFeatures(from magnitudes: [Float]) -> SpectralFeatures {
        let binCount = vDSP_Length(magnitudes.count)
        let frequencyResolution = sampleRate / Float(maxFrameSize)
        
        var features = SpectralFeatures()
        
        // Calculate band energies
        let bandRanges = [
            (0, Int(250.0 / frequencyResolution)), // Bass: 0-250 Hz
            (Int(250.0 / frequencyResolution), Int(4000.0 / frequencyResolution)), // Mid: 250-4000 Hz
            (Int(4000.0 / frequencyResolution), magnitudes.count) // Treble: 4000+ Hz
        ]
        
        // Calculate band energies
        features.bassEnergy = calculateBandEnergy(magnitudes, range: bandRanges[0])
        features.midEnergy = calculateBandEnergy(magnitudes, range: bandRanges[1])
        features.trebleEnergy = calculateBandEnergy(magnitudes, range: bandRanges[2])
        
        // Calculate spectral centroid (brightness)
        features.centroid = calculateSpectralCentroid(magnitudes, frequencyResolution: frequencyResolution)
        features.brightness = normalizeToRange(features.centroid, min: 500, max: 5000)
        
        // Calculate spectral spread
        features.spread = calculateSpectralSpread(magnitudes, centroid: features.centroid, frequencyResolution: frequencyResolution)
        
        // Calculate spectral flatness
        features.flatness = calculateSpectralFlatness(magnitudes)
        
        // Calculate spectral rolloff
        features.rolloff = calculateSpectralRolloff(magnitudes, frequencyResolution: frequencyResolution)
        
        // Calculate spectral flux if we have previous magnitudes
        if let prev = previousMagnitudes {
            features.flux = calculateSpectralFlux(current: magnitudes, previous: prev)
        }
        
        // Calculate spectral irregularity
        features.irregularity = calculateSpectralIrregularity(magnitudes)
        
        // Calculate spectral crest
        features.crest = calculateSpectralCrest(magnitudes)
        
        // Calculate higher order statistics
        calculateHigherOrderStats(&features, magnitudes)
        
        return features
    }
    
    private func calculateBandEnergy(_ magnitudes: [Float], range: (Int, Int)) -> Float {
        var sum: Float = 0
        let validStart = max(0, range.0)
        let validEnd = min(range.1, magnitudes.count)
        
        if validEnd > validStart {
            vDSP_sve(magnitudes + validStart, 1, &sum, vDSP_Length(validEnd - validStart))
            return sum / Float(magnitudes.count) // Normalize by total energy
        }
        return 0
    }
    
    private func calculateSpectralCentroid(magnitudes: [Float]) -> Float {
        let binCount = vDSP_Length(magnitudes.count)
        let freqResolution = sampleRate / (2.0 * Float(magnitudes.count))
        
        // Create frequency array (each bin's center frequency)
        var frequencies = [Float](repeating: 0, count: magnitudes.count)
        vDSP_vramp(Float(0), freqResolution, &frequencies, 1, binCount)
        
        // Calculate weighted sum (frequencies * magnitudes)
        var weightedSum: Float = 0
        vDSP_dotpr(frequencies, 1, magnitudes, 1, &weightedSum, binCount)
        
        // Calculate total magnitude
        var totalMagnitude: Float = 0
        vDSP_sve(magnitudes, 1, &totalMagnitude, binCount)
        
        // Centroid = weighted sum / total magnitude
        return totalMagnitude > 0 ? weightedSum / totalMagnitude : 0
    }
    
    private func calculateSpectralSpread(_ magnitudes: [Float], centroid: Float, frequencyResolution: Float) -> Float {
        var variance: Float = 0
        var totalEnergy: Float = 0
        
        for i in 0..<magnitudes.count {
            let frequency = Float(i) * frequencyResolution
            let magnitude = magnitudes[i]
            let diff = frequency - centroid
            variance += diff * diff * magnitude
            totalEnergy += magnitude
        }
        
        return totalEnergy > 0 ? sqrt(variance / totalEnergy) : 0
    }
    
    private func calculateSpectralFlatness(_ magnitudes: [Float]) -> Float {
        let count = vDSP_Length(magnitudes.count)
        
        // Calculate geometric mean
        var logSum: Float = 0
        vDSP_vlog(magnitudes, 1, &self.tempBuffer, 1, count)
        vDSP_sve(self.tempBuffer, 1, &logSum, count)
        let geometricMean = exp(logSum / Float(count))
        
        // Calculate arithmetic mean
        var arithmeticMean: Float = 0
        vDSP_meanv(magnitudes, 1, &arithmeticMean, count)
        
        return arithmeticMean > 0 ? geometricMean / arithmeticMean : 0
    }
    
    private func calculateSpectralRolloff(magnitudes: [Float]) -> Float {
        let threshold: Float = 0.85  // 85% of total energy
        var totalEnergy: Float = 0
        vDSP_svesq(magnitudes, 1, &totalEnergy, vDSP_Length(magnitudes.count))
        
        let targetEnergy = totalEnergy * threshold
        var cumulativeEnergy: Float = 0
        
        for (i, magnitude) in magnitudes.enumerated() {
            cumulativeEnergy += magnitude * magnitude
            if cumulativeEnergy >= targetEnergy {
                return Float(i) * sampleRate / Float(2 * magnitudes.count)
            }
        }
        
        return sampleRate / 2.0  // Nyquist frequency as default
    }
    
    private func calculateSpectralFlux(current: [Float], previous: [Float]) -> Float {
        var diff: Float = 0
        vDSP_vsub(previous, 1, current, 1, &self.tempBuffer, 1, vDSP_Length(min(current.count, previous.count)))
        vDSP_svesq(self.tempBuffer, 1, &diff, vDSP_Length(min(current.count, previous.count)))
        return sqrt(diff) / Float(current.count)
    }
    
    private func calculateHigherOrderStats(_ features: inout SpectralFeatures, _ magnitudes: [Float]) {
        var mean: Float = 0
        var m2: Float = 0
        var m3: Float = 0
        var m4: Float = 0
        
        // Calculate mean
        vDSP_meanv(magnitudes, 1, &mean, vDSP_Length(magnitudes.count))
        
        // Calculate central moments
        for magnitude in magnitudes {
            let diff = magnitude - mean
            let diff2 = diff * diff
            m2 += diff2
            m3 += diff2 * diff
            m4 += diff2 * diff2
        }
        
        let n = Float(magnitudes.count)
        m2 /= n
        m3 /= n
        m4 /= n
        
        // Calculate skewness and kurtosis
        let stdDev = sqrt(m2)
        features.skewness = m2 > 0 ? m3 / pow(stdDev, 3) : 0
        features.kurtosis = m2 > 0 ? m4 / (m2 * m2) : 0
    }
}