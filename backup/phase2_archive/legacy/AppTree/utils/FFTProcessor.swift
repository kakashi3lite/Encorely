import Accelerate
import AVFoundation
import Foundation

/// Enhanced FFT processor with comprehensive spectral feature extraction
class FFTProcessor {
    // MARK: - Properties

    private let fftSetup: vDSP_DFT_Setup?
    private let maxFrameSize: Int
    private let sampleRate: Float
    private var window: [Float]
    private let magnitudeNormalizationFactor: Float
    private var tempBuffer: [Float]
    private var previousMagnitudes: [Float]?

    // MFCC configuration
    private let numMFCCCoefficients = 13
    private let numMelFilters = 26
    private let melFilterbank: [[Float]]

    // Frequency band thresholds
    private let bassUpperLimit: Float = 250.0
    private let midUpperLimit: Float = 4000.0

    // MARK: - Initialization

    init(maxFrameSize: Int, sampleRate: Float = 44100.0) {
        self.maxFrameSize = maxFrameSize
        self.sampleRate = sampleRate

        // Initialize FFT setup
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            UInt(maxFrameSize),
            vDSP_DFT_Direction.FORWARD
        )

        // Initialize window function (Hanning)
        window = [Float](repeating: 0, count: maxFrameSize)
        vDSP_hann_window(&window, vDSP_Length(maxFrameSize), Int32(vDSP_HANN_NORM))

        // Initialize working buffer
        tempBuffer = [Float](repeating: 0, count: maxFrameSize)

        // Calculate FFT normalization factor
        magnitudeNormalizationFactor = 2.0 / Float(maxFrameSize)

        // Initialize mel filterbank
        melFilterbank = createMelFilterbank(
            numFilters: numMelFilters,
            fftSize: maxFrameSize,
            sampleRate: sampleRate,
            minFreq: 20.0,
            maxFreq: sampleRate / 2.0
        )
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Core FFT Processing

    func processBuffer(_ buffer: AVAudioPCMBuffer) -> SpectralFeatures? {
        guard let channelData = buffer.floatChannelData?[0],
              buffer.frameLength > 0 else { return nil }

        // Get magnitude spectrum
        guard let magnitudes = try? performVDSPFFT(channelData, frameCount: Int(buffer.frameLength)) else {
            return nil
        }

        // Extract all spectral features
        var features = SpectralFeatures()

        // Calculate band energies
        let (bassEnergy, midEnergy, trebleEnergy) = calculateBandEnergies(magnitudes)
        features.bassEnergy = bassEnergy
        features.midEnergy = midEnergy
        features.trebleEnergy = trebleEnergy

        // Calculate spectral shape features
        features.centroid = calculateSpectralCentroid(magnitudes)
        features.spread = calculateSpectralSpread(magnitudes, centroid: features.centroid)
        features.rolloff = calculateSpectralRolloff(magnitudes)
        features.flatness = calculateSpectralFlatness(magnitudes)

        // Calculate spectral variation features
        if let prevMags = previousMagnitudes {
            features.flux = calculateSpectralFlux(current: magnitudes, previous: prevMags)
        }

        // Extract MFCCs
        features.mfcc = extractMFCC(magnitudes)

        // Store current magnitudes for next frame
        previousMagnitudes = magnitudes

        // Estimate tempo using autocorrelation
        features.estimatedTempo = detectTempo(magnitudes)

        return features
    }

    // MARK: - DSP Core Functions

    private func performVDSPFFT(_ samples: UnsafePointer<Float>, frameCount: Int) throws -> [Float] {
        var realPart = [Float](repeating: 0, count: maxFrameSize)
        var imagPart = [Float](repeating: 0, count: maxFrameSize)

        // Copy samples and apply window
        samples.withMemoryRebound(to: Float.self, capacity: frameCount) { ptr in
            realPart.withUnsafeMutableBufferPointer { realPtr in
                realPtr.baseAddress?.initialize(from: ptr, count: min(frameCount, maxFrameSize))
            }
        }

        // Apply window function
        vDSP_vmul(realPart, 1, window, 1, &realPart, 1, vDSP_Length(maxFrameSize))

        // Perform FFT
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        guard let fftSetup else {
            throw AudioProcessingError.fftSetupFailed
        }

        vDSP_DFT_Execute(fftSetup, &realPart, &imagPart, &splitComplex.realp, &splitComplex.imagp)

        // Calculate magnitude spectrum
        let halfFrameCount = maxFrameSize / 2
        var magnitudes = [Float](repeating: 0, count: halfFrameCount)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfFrameCount))

        // Normalize
        vDSP_vsmul(magnitudes, 1, &magnitudeNormalizationFactor, &magnitudes, 1, vDSP_Length(halfFrameCount))

        return magnitudes
    }

    private func extractMFCC(_ magnitudes: [Float]) -> [Float] {
        // Convert to power spectrum
        var powerSpectrum = magnitudes
        vDSP_vsq(magnitudes, 1, &powerSpectrum, 1, vDSP_Length(magnitudes.count))

        // Apply mel filterbank
        var melEnergies = [Float](repeating: 0, count: numMelFilters)
        for i in 0 ..< numMelFilters {
            var energy: Float = 0
            vDSP_dotpr(powerSpectrum, 1, melFilterbank[i], 1, &energy, vDSP_Length(magnitudes.count))
            melEnergies[i] = max(log(energy + Float.ulpOfOne), 0)
        }

        // Apply DCT to get MFCCs
        var mfcc = [Float](repeating: 0, count: numMFCCCoefficients)
        for i in 0 ..< numMFCCCoefficients {
            var sum: Float = 0
            for j in 0 ..< numMelFilters {
                sum += melEnergies[j] * cos(Float.pi * Float(i) * (Float(j) + 0.5) / Float(numMelFilters))
            }
            mfcc[i] = sum
        }

        return mfcc
    }

    private func createMelFilterbank(numFilters: Int, fftSize: Int, sampleRate: Float, minFreq: Float,
                                     maxFreq: Float) -> [[Float]]
    {
        func freqToMel(_ freq: Float) -> Float {
            2595 * log10(1 + freq / 700)
        }

        func melToFreq(_ mel: Float) -> Float {
            700 * (pow(10, mel / 2595) - 1)
        }

        let minMel = freqToMel(minFreq)
        let maxMel = freqToMel(maxFreq)
        let melPoints = (0 ... numFilters + 1).map { i in
            melToFreq(minMel + Float(i) * (maxMel - minMel) / Float(numFilters + 1))
        }

        let binFreqs = (0 ..< fftSize / 2).map { Float($0) * sampleRate / Float(fftSize) }
        var filterbank = [[Float]](repeating: [Float](repeating: 0, count: fftSize / 2), count: numFilters)

        for i in 0 ..< numFilters {
            for j in 0 ..< fftSize / 2 {
                let freq = binFreqs[j]
                if freq >= melPoints[i], freq <= melPoints[i + 2] {
                    if freq <= melPoints[i + 1] {
                        filterbank[i][j] = (freq - melPoints[i]) / (melPoints[i + 1] - melPoints[i])
                    } else {
                        filterbank[i][j] = (melPoints[i + 2] - freq) / (melPoints[i + 2] - melPoints[i + 1])
                    }
                }
            }
        }

        return filterbank
    }

    private func detectTempo(_ magnitudes: [Float]) -> Float {
        let frameSize = magnitudes.count
        var autocorr = [Float](repeating: 0, count: frameSize)

        // Calculate autocorrelation using vDSP
        vDSP_conv(magnitudes, 1, magnitudes, 1, &autocorr, 1, vDSP_Length(frameSize), vDSP_Length(frameSize))

        // Find peaks in autocorrelation
        var peaks = [(Int, Float)]()
        for i in 1 ..< frameSize - 1 {
            if autocorr[i] > autocorr[i - 1], autocorr[i] > autocorr[i + 1] {
                peaks.append((i, autocorr[i]))
            }
        }

        // Sort peaks by amplitude
        peaks.sort { $0.1 > $1.1 }

        // Convert peak position to BPM
        if let strongestPeak = peaks.first {
            let peakIndex = strongestPeak.0
            let framesPerBeat = Float(peakIndex)
            let beatsPerFrame = 1.0 / framesPerBeat
            let framesPerSecond = sampleRate / Float(frameSize)
            let beatsPerSecond = beatsPerFrame * framesPerSecond
            let beatsPerMinute = beatsPerSecond * 60.0

            // Constrain to reasonable BPM range
            return min(max(beatsPerMinute, 40), 240)
        }

        return 120.0 // Default tempo if detection fails
    }

    private func calculateSpectralCentroid(_ magnitudes: [Float]) -> Float {
        let binCount = vDSP_Length(magnitudes.count)
        let freqResolution = sampleRate / (2.0 * Float(magnitudes.count))

        // Create frequency array
        var frequencies = [Float](repeating: 0, count: magnitudes.count)
        vDSP_vramp(Float(0), freqResolution, &frequencies, 1, binCount)

        // Calculate weighted sum
        var weightedSum: Float = 0
        vDSP_dotpr(frequencies, 1, magnitudes, 1, &weightedSum, binCount)

        // Calculate total magnitude
        var totalMagnitude: Float = 0
        vDSP_sve(magnitudes, 1, &totalMagnitude, binCount)

        return totalMagnitude > 0 ? weightedSum / totalMagnitude : 0
    }

    private func calculateSpectralRolloff(_ magnitudes: [Float]) -> Float {
        let threshold: Float = 0.85 // 85% of total energy
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

        return sampleRate / 2.0
    }

    private func calculateSpectralFlux(current: [Float], previous: [Float]) -> Float {
        var diff = [Float](repeating: 0, count: min(current.count, previous.count))
        vDSP_vsub(previous, 1, current, 1, &diff, 1, vDSP_Length(min(current.count, previous.count)))

        var flux: Float = 0
        vDSP_svesq(diff, 1, &flux, vDSP_Length(diff.count))
        return sqrt(flux)
    }

    private func calculateBandEnergies(_ magnitudes: [Float]) -> (bass: Float, mid: Float, treble: Float) {
        let freqResolution = sampleRate / Float(2 * magnitudes.count)
        let bassLimit = Int(bassUpperLimit / freqResolution)
        let midLimit = Int(midUpperLimit / freqResolution)

        var bassEnergy: Float = 0
        var midEnergy: Float = 0
        var trebleEnergy: Float = 0

        vDSP_svesq(magnitudes[0 ..< bassLimit], 1, &bassEnergy, vDSP_Length(bassLimit))
        vDSP_svesq(magnitudes[bassLimit ..< midLimit], 1, &midEnergy, vDSP_Length(midLimit - bassLimit))
        vDSP_svesq(magnitudes[midLimit...], 1, &trebleEnergy, vDSP_Length(magnitudes.count - midLimit))

        let totalEnergy = bassEnergy + midEnergy + trebleEnergy
        if totalEnergy > 0 {
            return (
                bassEnergy / totalEnergy,
                midEnergy / totalEnergy,
                trebleEnergy / totalEnergy
            )
        }
        return (0, 0, 0)
    }
}

/// Container for spectral features
struct SpectralFeatures {
    var centroid: Float = 0
    var spread: Float = 0
    var flux: Float = 0
    var flatness: Float = 0
    var rolloff: Float = 0
    var brightness: Float = 0
    var bassEnergy: Float = 0
    var midEnergy: Float = 0
    var trebleEnergy: Float = 0
    var mfcc: [Float] = []
    var estimatedTempo: Float = 0
}

enum AudioProcessingError: Error {
    case fftSetupFailed
}
