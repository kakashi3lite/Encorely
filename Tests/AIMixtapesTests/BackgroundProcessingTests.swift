@testable import App
import AVFoundation
import XCTest

class BackgroundProcessingTests: XCTestCase {
    var audioService: AudioAnalysisService!
    var expectation: XCTestExpectation!

    override func setUp() {
        super.setUp()
        audioService = AudioAnalysisService()
        expectation = expectation(description: "Background Processing")
    }

    override func tearDown() {
        audioService = nil
        super.tearDown()
    }

    func testBackgroundProcessingContinues() {
        // Create a long audio test file
        let duration: TimeInterval = 240 // 4 minutes
        let url = createTestAudioFile(duration: duration)

        // Start analysis
        var features: AudioFeatures?
        var error: Error?

        audioService.analyze(url: url)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    self.expectation.fulfill()
                case let .failure(err):
                    error = err
                    self.expectation.fulfill()
                }
            }, receiveValue: { result in
                features = result
            })
            .store(in: &cancellables)

        // Simulate entering background after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            NotificationCenter.default.post(
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
        }

        // Wait for completion
        wait(for: [expectation], timeout: 300)

        // Verify results
        XCTAssertNil(error, "Background processing should complete without errors")
        XCTAssertNotNil(features, "Should extract audio features")
        XCTAssertTrue(audioService.analysisHistory.count > 0, "Should save analysis history")
    }

    func testStateRecoveryAfterExpiration() {
        // Create test audio
        let url = createTestAudioFile(duration: 180)

        // Start analysis and force expiration
        audioService.analyze(url: url)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        // Wait for analysis to start
        Thread.sleep(forTimeInterval: 2)

        // Verify initial state saved
        XCTAssertTrue(audioService.isAnalyzing)
        let progress = audioService.progress

        // Simulate background task expiration
        simulateBackgroundExpiration()

        // Verify state saved
        let savedState = UserDefaults.standard.data(forKey: "AudioAnalysisState")
        XCTAssertNotNil(savedState, "State should be saved before expiration")

        // Create new service instance
        let newService = AudioAnalysisService()

        // Verify state restored
        XCTAssertEqual(newService.progress, progress, "Progress should be restored")
        XCTAssertEqual(newService.isAnalyzing, false, "Should be paused after restore")
    }

    func testMemoryPressureHandling() {
        let url = createTestAudioFile(duration: 120)

        // Start analysis
        audioService.analyze(url: url)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)

        // Simulate memory pressure
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        // Verify cleanup
        let memoryUsage = getMemoryUsage()
        XCTAssertLessThan(memoryUsage, 50 * 1024 * 1024, "Should reduce memory usage")
    }

    // MARK: - Helper Methods

    private var cancellables = Set<AnyCancellable>()

    private func createTestAudioFile(duration: TimeInterval) -> URL {
        let sampleRate = 44100.0
        let numSamples = Int(sampleRate * duration)

        // Create sine wave audio
        var samples = [Float](repeating: 0, count: numSamples)
        let frequency = 440.0 // A4 note

        for i in 0 ..< numSamples {
            let time = Double(i) / sampleRate
            samples[i] = sin(2.0 * .pi * frequency * time)
        }

        // Create audio file
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples))!

        let channelData = buffer.floatChannelData![0]
        samples.withUnsafeBufferPointer { samplesPtr in
            channelData.assign(from: samplesPtr.baseAddress!, count: numSamples)
        }
        buffer.frameLength = AVAudioFrameCount(numSamples)

        // Save to temp file
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test.caf")
        try! AVAudioFile(forWriting: url, settings: format.settings)
            .write(from: buffer)

        return url
    }

    private func simulateBackgroundExpiration() {
        NotificationCenter.default.post(
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        Thread.sleep(forTimeInterval: 0.5)

        // Post Darwin notification that triggers expiration
        NotificationCenter.default.post(
            name: Notification.Name("UIApplicationBackgroundTaskExpiredNotification"),
            object: nil
        )
    }

    private func getMemoryUsage() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = UInt32(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_,
                          task_flavor_t(TASK_VM_INFO),
                          intPtr,
                          &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return info.resident_size
    }
}
