@testable import AudioAnalysisModule
import XCTest

final class AudioAnalysisModuleTests: XCTestCase {
    var audioAnalysis: AudioAnalysisModule!

    override func setUp() {
        super.setUp()
        audioAnalysis = AudioAnalysisModule(windowSize: 1024, hopSize: 512, sampleRate: 44100)
    }

    override func tearDown() {
        audioAnalysis = nil
        super.tearDown()
    }

    func testModuleInitialization() {
        XCTAssertNotNil(audioAnalysis)
        XCTAssertEqual(audioAnalysis.analysisWindowSize, 1024)
        XCTAssertEqual(audioAnalysis.analysisHopSize, 512)
    }

    func testAnalyzeWindow() {
        // Create a simple sine wave for testing
        let frequency: Float = 440.0 // A4 note
        let sampleRate: Float = 44100.0
        let windowSize = audioAnalysis.analysisWindowSize

        let samples = (0 ..< windowSize).map { index in
            sin(2.0 * Float.pi * frequency * Float(index) / sampleRate)
        }

        let features = audioAnalysis.analyzeWindow(samples: samples)
        XCTAssertNotNil(features)

        if let features {
            // Basic sanity checks
            XCTAssertGreaterThan(features.rms, 0)
            XCTAssertLessThanOrEqual(features.rms, 1)

            XCTAssertGreaterThanOrEqual(features.zeroCrossingRate, 0)
            XCTAssertLessThanOrEqual(features.zeroCrossingRate, 1)

            XCTAssertGreaterThan(features.spectralCentroid, 0)
            XCTAssertGreaterThan(features.spectralRolloff, 0)

            XCTAssertEqual(features.mfcc.count, 13) // Assuming 13 MFCC coefficients
        }
    }

    func testAnalyzeMultipleWindows() {
        // Create a longer signal
        let frequency: Float = 440.0
        let sampleRate: Float = 44100.0
        let duration = 0.1 // 100ms
        let totalSamples = Int(sampleRate * duration)

        let samples = (0 ..< totalSamples).map { index in
            sin(2.0 * Float.pi * frequency * Float(index) / sampleRate)
        }

        let features = audioAnalysis.analyze(samples: samples)
        XCTAssertFalse(features.isEmpty)

        // Expected number of windows
        let expectedWindows = (totalSamples - audioAnalysis.analysisWindowSize) / audioAnalysis.analysisHopSize + 1
        XCTAssertEqual(features.count, expectedWindows)
    }

    func testInvalidWindowSize() {
        let samples = Array(repeating: Float(0), count: 100) // Too small window
        let features = audioAnalysis.analyzeWindow(samples: samples)
        XCTAssertNil(features)
    }
}
