import AVFoundation
import Testing
@testable import Encorely

/// Tests for AudioAnalyzer's feature extraction logic.
struct AudioAnalyzerTests {
    let analyzer = AudioAnalyzer()

    // MARK: - Feature Extraction from Buffer

    @Test("Extract features from a silent buffer returns low energy")
    func silentBufferLowEnergy() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100

        // Fill with silence (zeros)
        let data = buffer.floatChannelData![0]
        for i in 0..<44100 { data[i] = 0.0 }

        let features = analyzer.extractFeatures(from: buffer, sampleRate: 44100)
        #expect(features.energy < 0.01)
    }

    @Test("Loud sine wave has higher energy than silence")
    func sineWaveHigherEnergy() throws {
        let sampleRate: Float = 44100
        let count: AVAudioFrameCount = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!

        let silentBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        silentBuffer.frameLength = count
        let silentData = silentBuffer.floatChannelData![0]
        for i in 0..<Int(count) { silentData[i] = 0.0 }

        let sineBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        sineBuffer.frameLength = count
        let sineData = sineBuffer.floatChannelData![0]
        for i in 0..<Int(count) {
            sineData[i] = 0.8 * sin(2 * .pi * 440.0 * Float(i) / sampleRate)
        }

        let silentFeatures = analyzer.extractFeatures(from: silentBuffer, sampleRate: sampleRate)
        let sineFeatures = analyzer.extractFeatures(from: sineBuffer, sampleRate: sampleRate)

        #expect(sineFeatures.energy > silentFeatures.energy)
    }

    @Test("Feature values are within valid ranges")
    func featureRanges() throws {
        let sampleRate: Float = 44100
        let count: AVAudioFrameCount = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        buffer.frameLength = count
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(count) {
            data[i] = 0.5 * sin(2 * .pi * 440.0 * Float(i) / sampleRate)
        }

        let features = analyzer.extractFeatures(from: buffer, sampleRate: sampleRate)

        #expect(features.energy >= 0 && features.energy <= 1.0)
        #expect(features.valence >= 0 && features.valence <= 1.0)
        #expect(features.danceability >= 0 && features.danceability <= 1.0)
        #expect(features.acousticness >= 0 && features.acousticness <= 1.0)
        #expect(features.instrumentalness >= 0 && features.instrumentalness <= 1.0)
        #expect(features.speechiness >= 0 && features.speechiness <= 1.0)
        #expect(features.liveness >= 0 && features.liveness <= 1.0)
        #expect(features.tempo >= 60 && features.tempo <= 200)
    }

    // MARK: - Spectrum Update

    @Test("Spectrum update fills spectrum data array")
    func spectrumUpdate() throws {
        let sampleRate: Float = 44100
        let count: AVAudioFrameCount = 4096
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        buffer.frameLength = count
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(count) {
            data[i] = 0.5 * sin(2 * .pi * 440.0 * Float(i) / sampleRate)
        }

        analyzer.updateSpectrum(from: buffer)
        #expect(analyzer.spectrumData.count == 64)

        // At least some bands should be non-zero for a sine wave
        let nonZero = analyzer.spectrumData.filter { $0 > 0.001 }
        #expect(!nonZero.isEmpty)
    }
}
