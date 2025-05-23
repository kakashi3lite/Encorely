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
        guard let fftSetup = fftSetup else {
            throw FFTError.setupNotInitialized
        }
        
        // Determine frame size to process (use power of 2 <= frameCount)
        let frameSize = determineFrameSize(frameCount)
        guard frameSize > 0 else {
            throw FFTError.invalidFrameSize
        }
        
        // Create input and output buffers
        var realInput = [Float](repeating: 0, count: frameSize)
        var imagInput = [Float](repeating: 0, count: frameSize)
        var realOutput = [Float](repeating: 0, count: frameSize)
        var imagOutput = [Float](repeating: 0, count: frameSize)
        
        // Copy audio data to processing buffer with windowing
        let framesToCopy = min(frameCount, frameSize)
        for i in 0..<framesToCopy {
            realInput[i] = buffer[i] * window[i]
        }
        
        // Perform FFT
        vDSP_DFT_Execute(fftSetup,
                         &realInput, &imagInput,
                         &realOutput, &imagOutput)
        
        // Calculate magnitude spectrum (only need first half due to symmetry)
        let usefulBins = frameSize / 2
        var magnitudes = [Float](repeating: 0, count: usefulBins)
        
        for i in 0..<usefulBins {
            // Magnitude = sqrt(real^2 + imag^2)
            let real = realOutput[i]
            let imag = imagOutput[i]
            magnitudes[i] = sqrt(real * real + imag * imag) * magnitudeNormalizationFactor
        }
        
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
        // Frequency resolution
        let freqResolution = sampleRate / Float(2 * magnitudes.count)
        
        // Calculate band energies
        let (bassEnergy, midEnergy, trebleEnergy) = calculateBandEnergies(magnitudes, freqResolution)
        
        // Calculate spectral centroid and derived brightness
        let centroid = calculateSpectralCentroid(magnitudes, freqResolution)
        let brightness = normalizeToRange(centroid, min: 500, max: 5000)
        
        // Calculate spectral spread
        let spread = calculateSpectralSpread(magnitudes, freqResolution, centroid)
        
        // Calculate spectral roll-off
        let rolloff = calculateSpectralRolloff(magnitudes, freqResolution)
        
        // Calculate spectral flux if previous magnitudes exist
        let flux = calculateSpectralFlux(current: magnitudes)
        
        // Calculate spectral flatness
        let flatness = calculateSpectralFlatness(magnitudes)
        
        // Calculate spectral irregularity
        let irregularity = calculateSpectralIrregularity(magnitudes)
        
        // Calculate spectral crest
        let crest = calculateSpectralCrest(magnitudes)
        
        // Calculate harmonic ratio (approximation)
        let harmonicRatio = 1.0 - flatness // Inverse relationship with flatness
        
        // Calculate spectral contrast (approximation)
        let spectralContrast = crest * 20.0 // Scale up for better range
        
        // Estimate tempo and beat strength from sub-band energy fluctuations
        let (estimatedTempo, beatStrength) = estimateTempoFeatures(flux: flux, bassEnergy: bassEnergy)
        
        // Calculate zero crossing rate (approximation from spectral properties)
        let zeroCrossingRate = calculateZeroCrossingRate(centroid, brightness)
        
        // Calculate dynamic range
        let dynamicRange = calculateDynamicRange(magnitudes)
        
        // Calculate spectral skewness
        let skewness = calculateSpectralSkewness(magnitudes, freqResolution, centroid, spread)
        
        // Calculate spectral kurtosis
        let kurtosis = calculateSpectralKurtosis(magnitudes, freqResolution, centroid, spread)
        
        return SpectralFeatures(
            bassEnergy: bassEnergy,
            midEnergy: midEnergy,
            trebleEnergy: trebleEnergy,
            brightness: brightness,
            centroid: centroid,
            spread: spread,
            rolloff: rolloff,
            flux: flux,
            flatness: flatness,
            irregularity: irregularity,
            crest: crest,
            skewness: skewness,
            kurtosis: kurtosis,
            harmonicRatio: harmonicRatio,
            spectralContrast: spectralContrast,
            zeroCrossingRate: zeroCrossingRate,
            dynamicRange: dynamicRange,
            estimatedTempo: estimatedTempo,
            beatStrength: beatStrength
        )
    }
    
    // MARK: - Spectral Calculations
    
    /// Calculates energy in bass, mid and treble frequency bands
    private func calculateBandEnergies(_ magnitudes: [Float], _ freqResolution: Float) -> (bass: Float, mid: Float, treble: Float) {
        let size = magnitudes.count
        var bassSum: Float = 0
        var midSum: Float = 0
        var trebleSum: Float = 0
        var totalSum: Float = 0
        
        for i in 0..<size {
            let freq = Float(i) * freqResolution
            let magnitude = magnitudes[i]
            let energy = magnitude * magnitude // Energy is magnitude squared
            
            totalSum += energy
            
            if freq < bassUpperLimit {
                bassSum += energy
            } else if freq < midUpperLimit {
                midSum += energy
            } else {
                trebleSum += energy
            }
        }
        
        // Normalize by total energy to get relative distribution
        if totalSum > 0 {
            bassSum /= totalSum
            midSum /= totalSum
            trebleSum /= totalSum
        }
        
        return (bassSum, midSum, trebleSum)
    }
    
    /// Helper to normalize a value to 0.0-1.0 range
    private func normalizeToRange(_ value: Float, min: Float, max: Float) -> Float {
        return min(1.0, max(0.0, (value - min) / (max - min)))
    }
    
    /// Estimates tempo and beat strength from spectral flux
    private func estimateTempoFeatures(flux: Float, bassEnergy: Float) -> (tempo: Float, beatStrength: Float) {
        // This is a simple approximation
        // A real tempo detection would require tempo tracking over time
        let estimatedTempo = 60.0 + flux * 120.0 // Map to 60-180 BPM range
        let beatStrength = bassEnergy * 0.7 + flux * 0.3 // Weight bass energy more for beat strength
        
        return (estimatedTempo, beatStrength)
    }
    
    /// Calculates zero crossing rate approximation
    private func calculateZeroCrossingRate(_ centroid: Float, _ brightness: Float) -> Float {
        // Zero crossing rate correlates with centroid and brightness
        return centroid * 0.5 + brightness * 1500.0
    }
    
    /// Calculates dynamic range from magnitude spectrum
    private func calculateDynamicRange(_ magnitudes: [Float]) -> Float {
        guard !magnitudes.isEmpty else { return 0 }
        
        var max: Float = -Float.greatestFiniteMagnitude
        var min: Float = Float.greatestFiniteMagnitude
        
        for magnitude in magnitudes where magnitude > 0 {
            let db = 20 * log10(magnitude)
            max = Swift.max(max, db)
            min = Swift.min(min, db)
        }
        
        return max - min
    }
    
    /// Calculates spectral flux compared to previous frame
    private func calculateSpectralFlux(current: [Float]) -> Float {
        guard let previous = previousMagnitudes else {
            return 0
        }
        
        let minSize = min(current.count, previous.count)
        var sum: Float = 0
        
        for i in 0..<minSize {
            let diff = current[i] - previous[i]
            // Only positive changes contribute to flux (half-wave rectification)
            sum += diff > 0 ? diff : 0
        }
        
        return sum / Float(minSize)
    }
    
    /// Calculates the spectral centroid (weighted mean of frequencies)
    private func calculateSpectralCentroid(_ magnitudes: [Float], _ freqResolution: Float) -> Float {
        let size = magnitudes.count
        guard size > 0 else { return 0 }
        
        var weightedSum: Float = 0
        var sum: Float = 0
        
        for i in 0..<size {
            let frequency = Float(i) * freqResolution
            let magnitude = magnitudes[i]
            
            weightedSum += frequency * magnitude
            sum += magnitude
        }
        
        // Avoid division by zero
        guard sum > 0 else { return 0 }
        
        return weightedSum / sum
    }
    
    /// Calculates the spectral spread around the centroid
    private func calculateSpectralSpread(_ magnitudes: [Float], _ freqResolution: Float, _ centroid: Float) -> Float {
        let size = magnitudes.count
        guard size > 0 else { return 0 }
        
        var variance: Float = 0
        var sum: Float = 0
        
        for i in 0..<size {
            let frequency = Float(i) * freqResolution
            let magnitude = magnitudes[i]
            let deviation = frequency - centroid
            
            variance += deviation * deviation * magnitude
            sum += magnitude
        }
        
        // Avoid division by zero
        guard sum > 0 else { return 0 }
        
        return sqrt(variance / sum)
    }
    
    /// Calculates the spectral rolloff (frequency below which 85% of energy lies)
    private func calculateSpectralRolloff(_ magnitudes: [Float], _ freqResolution: Float, percentile: Float = 0.85) -> Float {
        let size = magnitudes.count
        guard size > 0 else { return 0 }
        
        // Calculate total energy
        var totalEnergy: Float = 0
        for magnitude in magnitudes {
            totalEnergy += magnitude * magnitude
        }
        
        // Find rolloff point
        var cumulativeEnergy: Float = 0
        let threshold = totalEnergy * percentile
        
        for i in 0..<size {
            let energy = magnitudes[i] * magnitudes[i]
            cumulativeEnergy += energy
            
            if cumulativeEnergy >= threshold {
                return Float(i) * freqResolution
            }
        }
        
        return sampleRate / 2 // Nyquist frequency
    }
    
    /// Calculates spectral flatness (ratio of geometric to arithmetic mean)
    private func calculateSpectralFlatness(_ magnitudes: [Float]) -> Float {
        let size = magnitudes.count
        guard size > 0 else { return 0 }
        
        // Filter out near-zero values to avoid log(0)
        let filteredMags = magnitudes.filter { $0 > 1e-10 }
        guard filteredMags.count > 0 else { return 0 }
        
        // Calculate geometric mean
        var logSum: Float = 0
        for magnitude in filteredMags {
            logSum += log(magnitude)
        }
        let geometricMean = exp(logSum / Float(filteredMags.count))
        
        // Calculate arithmetic mean
        var sum: Float = 0
        for magnitude in filteredMags {
            sum += magnitude
        }
        let arithmeticMean = sum / Float(filteredMags.count)
        
        // Avoid division by zero
        guard arithmeticMean > 0 else { return 0 }
        
        // Return flatness (ratio of geometric to arithmetic mean)
        return geometricMean / arithmeticMean
    }
    
    /// Calculates spectral irregularity (measure of variation between adjacent bins)
    private func calculateSpectralIrregularity(_ magnitudes: [Float]) -> Float {
        let size = magnitudes.count
        guard size > 2 else { return 0 }
        
        var sum: Float = 0
        for i in 1..<(size-1) {
            // Jensen method: squared difference from the mean of three adjacent values
            let meanAmplitude = (magnitudes[i-1] + magnitudes[i] + magnitudes[i+1]) / 3
            let diff = magnitudes[i] - meanAmplitude
            sum += diff * diff
        }
        
        return sqrt(sum) / Float(size - 2)
    }
    
    /// Calculates spectral crest factor (ratio of peak to mean)
    private func calculateSpectralCrest(_ magnitudes: [Float]) -> Float {
        let size = magnitudes.count
        guard size > 0 else { return 0 }
        
        // Find peak value
        var peak: Float = 0
        for magnitude in magnitudes {
            peak = max(peak, magnitude)
        }
        
        // Calculate mean
        var sum: Float = 0
        for magnitude in magnitudes {
            sum += magnitude
        }
        let mean = sum / Float(size)
        
        // Avoid division by zero
        guard mean > 0 else { return 0 }
        
        // Return crest factor
        return peak / mean
    }
    
    /// Calculates spectral skewness (measure of asymmetry)
    private func calculateSpectralSkewness(_ magnitudes: [Float], _ freqResolution: Float, _ centroid: Float, _ spread: Float) -> Float {
        let size = magnitudes.count
        guard size > 0, spread > 0 else { return 0 }
        
        var skewness: Float = 0
        var sum: Float = 0
        
        for i in 0..<size {
            let frequency = Float(i) * freqResolution
            let magnitude = magnitudes[i]
            let deviation = (frequency - centroid) / spread
            
            skewness += deviation * deviation * deviation * magnitude
            sum += magnitude
        }
        
        // Avoid division by zero
        guard sum > 0 else { return 0 }
        
        return skewness / sum
    }
    
    /// Calculates spectral kurtosis (measure of "peakedness")
    private func calculateSpectralKurtosis(_ magnitudes: [Float], _ freqResolution: Float, _ centroid: Float, _ spread: Float) -> Float {
        let size = magnitudes.count
        guard size > 0, spread > 0 else { return 0 }
        
        var kurtosis: Float = 0
        var sum: Float = 0
        
        for i in 0..<size {
            let frequency = Float(i) * freqResolution
            let magnitude = magnitudes[i]
            let deviation = (frequency - centroid) / spread
            
            kurtosis += deviation * deviation * deviation *