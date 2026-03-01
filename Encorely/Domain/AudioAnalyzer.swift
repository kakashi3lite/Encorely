import AVFoundation
import Foundation
import Observation
import os.log

/// Analyzes audio buffers and files to extract AudioFeatures.
/// Uses AVFoundation for file reading and simplified spectral analysis.
@Observable
final class AudioAnalyzer: @unchecked Sendable {
    // MARK: - Observable State

    private(set) var isAnalyzing = false
    private(set) var latestFeatures: AudioFeatures?
    /// Real-time spectral magnitudes for visualization (0.0–1.0 per band).
    private(set) var spectrumData: [Float] = Array(repeating: 0, count: 64)

    private let logger = Logger(subsystem: "com.encorely", category: "AudioAnalyzer")
    private let analysisQueue = DispatchQueue(label: "com.encorely.audioanalysis", qos: .userInitiated)

    // MARK: - Public API

    /// Analyzes an audio file at the given URL and returns extracted features.
    func analyze(url: URL) async throws -> AudioFeatures {
        isAnalyzing = true
        defer { isAnalyzing = false }

        logger.info("Analyzing audio file: \(url.lastPathComponent)")

        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let sampleRate = Float(format.sampleRate)
        let frameCount = AVAudioFrameCount(file.length)

        guard frameCount > 0 else {
            throw AudioAnalysisError.emptyFile
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioAnalysisError.bufferCreationFailed
        }
        try file.read(into: buffer)

        let features = extractFeatures(from: buffer, sampleRate: sampleRate)
        latestFeatures = features

        logger.info("Analysis complete — energy: \(features.energy), tempo: \(features.tempo)")
        return features
    }

    /// Extracts features from a PCM buffer (for real-time pipeline).
    func extractFeatures(from buffer: AVAudioPCMBuffer, sampleRate: Float) -> AudioFeatures {
        guard let channelData = buffer.floatChannelData?[0] else {
            return AudioFeatures()
        }

        let count = Int(buffer.frameLength)
        guard count > 0 else { return AudioFeatures() }

        // --- RMS Energy ---
        var rmsSum: Float = 0
        for i in 0..<count {
            rmsSum += channelData[i] * channelData[i]
        }
        let rms = sqrt(rmsSum / Float(count))
        let energy = min(1.0, rms * 3.0)

        // --- Zero Crossing Rate (proxy for noisiness / speechiness) ---
        var zeroCrossings = 0
        for i in 1..<count {
            if (channelData[i] >= 0) != (channelData[i - 1] >= 0) {
                zeroCrossings += 1
            }
        }
        let zcr = Float(zeroCrossings) / Float(count)
        let speechiness = min(1.0, zcr * 5.0)

        // --- Tempo estimation via autocorrelation peak ---
        let tempo = estimateTempo(channelData: channelData, count: count, sampleRate: sampleRate)

        // --- Spectral centroid (brightness proxy → valence) ---
        let centroid = spectralCentroid(channelData: channelData, count: count, sampleRate: sampleRate)
        let maxCentroid = sampleRate / 4.0
        let valence = min(1.0, centroid / maxCentroid)

        // --- Danceability heuristic: combines tempo regularity + energy ---
        let normalizedTempo = min(1.0, max(0.0, (tempo - 60) / 120.0))
        let danceability = (normalizedTempo * 0.5 + energy * 0.5)

        // --- Acousticness: inverse of high-freq energy ratio ---
        let acousticness = max(0.0, 1.0 - (zcr * 3.0))

        // --- Instrumentalness: low speechiness + moderate energy ---
        let instrumentalness = max(0.0, 1.0 - speechiness) * 0.8

        // --- Liveness: ZCR variance ---
        let liveness = min(1.0, zcr * 2.0)

        return AudioFeatures(
            tempo: tempo,
            energy: energy,
            valence: valence,
            danceability: danceability,
            acousticness: acousticness,
            instrumentalness: instrumentalness,
            speechiness: speechiness,
            liveness: liveness
        )
    }

    /// Updates spectrum data from a buffer for visualization.
    func updateSpectrum(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        let bands = spectrumData.count

        guard count >= bands * 2 else { return }

        var newSpectrum = [Float](repeating: 0, count: bands)
        let chunkSize = count / bands

        for band in 0..<bands {
            var sum: Float = 0
            let start = band * chunkSize
            for i in start..<(start + chunkSize) {
                sum += abs(channelData[i])
            }
            newSpectrum[band] = min(1.0, sum / Float(chunkSize) * 4.0)
        }

        spectrumData = newSpectrum
    }

    // MARK: - Internal Algorithms

    /// Simple autocorrelation-based tempo estimation.
    private func estimateTempo(channelData: UnsafePointer<Float>, count: Int, sampleRate: Float) -> Float {
        // Search for BPM between 60 and 200
        let minLag = Int(sampleRate * 60.0 / 200.0)
        let maxLag = min(count / 2, Int(sampleRate * 60.0 / 60.0))

        guard maxLag > minLag else { return 120 }

        var bestLag = minLag
        var bestCorrelation: Float = -.greatestFiniteMagnitude

        // Downsample for performance (analyze every 4th sample)
        let step = 4
        let analysisLength = min(count / 2, maxLag + 1000)

        for lag in stride(from: minLag, to: maxLag, by: 2) {
            var correlation: Float = 0
            var sampleCount = 0
            for i in stride(from: 0, to: analysisLength - lag, by: step) {
                correlation += channelData[i] * channelData[i + lag]
                sampleCount += 1
            }
            correlation /= Float(max(1, sampleCount))

            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }

        let bpm = 60.0 * sampleRate / Float(bestLag)
        // Clamp to reasonable range
        return min(200, max(60, bpm))
    }

    /// Computes the spectral centroid (center of mass of the spectrum).
    private func spectralCentroid(channelData: UnsafePointer<Float>, count: Int, sampleRate: Float) -> Float {
        let fftSize = min(count, 2048)
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0

        for i in 0..<fftSize {
            let magnitude = abs(channelData[i])
            let frequency = Float(i) * sampleRate / Float(fftSize)
            weightedSum += magnitude * frequency
            magnitudeSum += magnitude
        }

        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0
    }
}

// MARK: - Errors

/// Errors that can occur during audio analysis.
enum AudioAnalysisError: LocalizedError {
    case emptyFile, bufferCreationFailed, unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .emptyFile:            "The audio file is empty."
        case .bufferCreationFailed: "Failed to create audio buffer."
        case .unsupportedFormat:    "Unsupported audio format."
        }
    }
}
