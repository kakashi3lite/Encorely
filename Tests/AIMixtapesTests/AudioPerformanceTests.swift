@testable import App
import XCTest

final class AudioPerformanceTests: XCTestCase {
    private var performanceMonitor: AudioPerformanceMonitor!
    private var audioProcessor: AudioProcessor!
    private var audioAnalysisService: AudioAnalysisService!

    private let testDuration: TimeInterval = 10.0
    private let sampleRate: Double = 44100.0
    private let testFrequency: Double = 440.0 // A4 note

    override func setUp() {
        super.setUp()
        performanceMonitor = AudioPerformanceMonitor()
        audioAnalysisService = AudioAnalysisService()
        audioProcessor = AudioProcessor(audioAnalysisService: audioAnalysisService)

        performanceMonitor.startMonitoring()
    }

    override func tearDown() {
        performanceMonitor.stopMonitoring()
        audioProcessor = nil
        audioAnalysisService = nil
        performanceMonitor = nil
        super.tearDown()
    }

    func testProcessingTimePerformance() {
        let expectation = XCTestExpectation(description: "Processing time test")
        let bufferDuration: TimeInterval = 0.1
        let iterations = 50
        var processingTimes: [TimeInterval] = []

        // Process multiple buffers and measure time
        for _ in 0 ..< iterations {
            autoreleasepool {
                guard let buffer = createTestBuffer(duration: bufferDuration) else {
                    XCTFail("Failed to create test buffer")
                    return
                }

                let start = CFAbsoluteTimeGetCurrent()

                let processExpectation = XCTestExpectation(description: "Buffer processing")
                audioProcessor.processAudioBuffer(buffer) { _ in
                    let duration = CFAbsoluteTimeGetCurrent() - start
                    processingTimes.append(duration)
                    processExpectation.fulfill()
                }

                wait(for: [processExpectation], timeout: 1.0)
            }
        }

        // Calculate statistics
        let averageTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
        let maxTime = processingTimes.max() ?? 0

        // Verify performance
        XCTAssertLessThan(averageTime, 0.1, "Average processing time should be under 100ms")
        XCTAssertLessThan(maxTime, 0.2, "Maximum processing time should be under 200ms")

        expectation.fulfill()
        wait(for: [expectation], timeout: testDuration + 5.0)
    }

    func testConcurrentProcessingPerformance() {
        let expectation = XCTestExpectation(description: "Concurrent processing")
        let operationCount = 20
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        var completedOperations = 0
        var totalProcessingTime: TimeInterval = 0
        let semaphore = DispatchSemaphore(value: 4) // Limit concurrent operations

        let startTime = CFAbsoluteTimeGetCurrent()

        // Launch concurrent operations
        for i in 0 ..< operationCount {
            group.enter()
            queue.async {
                semaphore.wait()
                autoreleasepool {
                    guard let buffer = self.createTestBuffer(duration: 0.2) else {
                        XCTFail("Failed to create buffer")
                        group.leave()
                        semaphore.signal()
                        return
                    }

                    let operationStart = CFAbsoluteTimeGetCurrent()

                    self.audioProcessor.processAudioBuffer(buffer) { _ in
                        let operationTime = CFAbsoluteTimeGetCurrent() - operationStart

                        DispatchQueue.main.async {
                            completedOperations += 1
                            totalProcessingTime += operationTime

                            if completedOperations == operationCount {
                                let totalTime = CFAbsoluteTimeGetCurrent() - startTime

                                // Verify performance
                                XCTAssertLessThan(totalTime, Double(operationCount) * 0.3,
                                                  "Total time should benefit from concurrency")
                                XCTAssertLessThan(totalProcessingTime / Double(completedOperations),
                                                  0.1, "Average processing time should be reasonable")

                                expectation.fulfill()
                            }
                        }

                        group.leave()
                        semaphore.signal()
                    }
                }
            }

            // Small delay between launches to prevent overwhelming
            if i % 5 == 0 {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        wait(for: [expectation], timeout: Double(operationCount) + 5.0)
    }

    func testMemoryPerformance() {
        let expectation = XCTestExpectation(description: "Memory performance")
        let initialMemory = getMemoryUsage()
        var memoryReadings: [Int] = []
        let processCount = 30

        // Process multiple buffers while monitoring memory
        for i in 0 ..< processCount {
            autoreleasepool {
                if let buffer = createTestBuffer(duration: 0.5) {
                    let processExpectation = XCTestExpectation(description: "Buffer process \(i)")

                    audioProcessor.processAudioBuffer(buffer) { _ in
                        let currentMemory = self.getMemoryUsage()
                        memoryReadings.append(currentMemory)
                        processExpectation.fulfill()
                    }

                    wait(for: [processExpectation], timeout: 2.0)
                }
            }

            if i % 5 == 0 {
                // Allow time for cleanup
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        // Calculate memory statistics
        let maxMemory = memoryReadings.max() ?? 0
        let averageMemory = memoryReadings.reduce(0, +) / memoryReadings.count
        let memoryIncrease = maxMemory - initialMemory

        // Verify memory performance
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, "Memory increase should be under 50MB")
        XCTAssertLessThan(Double(averageMemory - initialMemory) / Double(maxMemory - initialMemory),
                          0.7, "Average memory usage should be reasonable")

        expectation.fulfill()
        wait(for: [expectation], timeout: Double(processCount) * 0.5 + 5.0)
    }

    func testLongRunningPerformance() {
        let expectation = XCTestExpectation(description: "Long running performance")
        let duration: TimeInterval = 30.0 // 30 second test
        let startTime = Date()
        var processedBuffers = 0
        var memoryReadings: [Int] = []

        // Start continuous processing
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            autoreleasepool {
                if let buffer = self.createTestBuffer(duration: 0.1) {
                    self.audioProcessor.processAudioBuffer(buffer) { _ in
                        processedBuffers += 1
                        memoryReadings.append(self.getMemoryUsage())
                    }
                }
            }

            if Date().timeIntervalSince(startTime) >= duration {
                timer.invalidate()

                // Calculate performance metrics
                let averageMemory = memoryReadings.reduce(0, +) / memoryReadings.count
                let maxMemory = memoryReadings.max() ?? 0
                let bufferRate = Double(processedBuffers) / duration

                // Verify performance
                XCTAssertGreaterThan(bufferRate, 5.0, "Should process at least 5 buffers per second")
                XCTAssertLessThan(Double(maxMemory) / Double(averageMemory), 1.5,
                                  "Memory usage should be stable")

                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: duration + 5.0)
    }

    func testPerformanceMonitoring() {
        let expectation = XCTestExpectation(description: "Performance monitoring")
        let monitoringDuration: TimeInterval = 10.0
        let startTime = Date()
        var statusChanges = 0

        // Listen for performance status changes
        let observer = NotificationCenter.default.addObserver(
            forName: .performanceStatusChanged,
            object: nil,
            queue: .main
        ) { _ in
            statusChanges += 1
        }

        // Generate varying load
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            autoreleasepool {
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed >= monitoringDuration {
                    timer.invalidate()

                    // Verify monitoring
                    let report = self.performanceMonitor.generateReport()

                    XCTAssertGreaterThan(report.bufferMetrics.processedCount, 0,
                                         "Should process some buffers")
                    XCTAssertGreaterThan(statusChanges, 0,
                                         "Should detect performance status changes")

                    NotificationCenter.default.removeObserver(observer)
                    expectation.fulfill()
                } else {
                    // Vary processing load
                    let duration = (elapsed < monitoringDuration / 2) ? 0.1 : 0.3
                    if let buffer = self.createTestBuffer(duration: duration) {
                        self.audioProcessor.processAudioBuffer(buffer) { _ in }
                    }
                }
            }
        }

        wait(for: [expectation], timeout: monitoringDuration + 5.0)
    }

    // MARK: - Helper Methods

    private func createTestBuffer(duration: TimeInterval) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount

        if let channelData = buffer.floatChannelData {
            for channel in 0 ..< Int(format.channelCount) {
                for frame in 0 ..< Int(frameCount) {
                    let time = Double(frame) / sampleRate
                    let value = sin(2.0 * .pi * testFrequency * time)
                    channelData[channel][frame] = Float(value)
                }
            }
        }

        return buffer
    }

    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}
