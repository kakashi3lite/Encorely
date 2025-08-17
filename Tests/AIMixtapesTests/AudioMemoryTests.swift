@testable import App
import XCTest

final class AudioMemoryTests: XCTestCase {
    private var audioBufferPool: AudioBufferPool!
    private var audioProcessor: AudioProcessor!
    private var audioAnalysisService: AudioAnalysisService!
    private var performanceMonitor: AudioPerformanceMonitor!

    private let testSampleRate: Double = 44100
    private let maxMemoryLimit = 50 * 1024 * 1024 // 50MB

    override func setUp() {
        super.setUp()
        let format = AVAudioFormat(standardFormatWithSampleRate: testSampleRate, channels: 2)!
        audioBufferPool = AudioBufferPool(format: format, frameCapacity: 4096)
        performanceMonitor = AudioPerformanceMonitor()
        audioAnalysisService = AudioAnalysisService()
        audioProcessor = AudioProcessor(audioAnalysisService: audioAnalysisService)

        performanceMonitor.startMonitoring()
    }

    override func tearDown() {
        performanceMonitor.stopMonitoring()
        audioProcessor = nil
        audioAnalysisService = nil
        audioBufferPool = nil
        super.tearDown()
    }

    // MARK: - Buffer Pool Tests

    func testBufferPoolMemoryManagement() {
        let initialMemory = getMemoryUsage()
        var buffers: [ManagedAudioBuffer] = []

        // Create buffers until memory pressure
        while getMemoryUsage() - initialMemory < maxMemoryLimit {
            if let buffer = audioBufferPool.getBuffer() {
                buffers.append(buffer)
            }
        }

        // Verify memory pressure handling
        let midMemory = getMemoryUsage()
        XCTAssertGreaterThan(buffers.count, 0, "Should allocate some buffers")
        XCTAssertLessThan(midMemory - initialMemory, maxMemoryLimit, "Should stay under memory limit")

        // Clear buffers
        buffers.forEach { audioBufferPool.returnBuffer($0) }
        buffers.removeAll()

        // Force cleanup
        audioBufferPool.releaseAllBuffers()

        // Memory should be significantly reduced
        let finalMemory = getMemoryUsage() - initialMemory
        XCTAssertLessThan(finalMemory, maxMemoryLimit / 4, "Memory should be properly released")
    }

    func testMemoryPressureHandling() {
        let expectation = XCTestExpectation(description: "Memory pressure handling")
        var memoryReadings: [Int] = []
        var lastMemory = getMemoryUsage()

        // Create memory pressure
        for i in 0 ..< 20 {
            autoreleasepool {
                if let buffer = createTestBuffer(duration: 1.0) {
                    audioProcessor.processAudioBuffer(buffer) { _ in }
                    let currentMemory = getMemoryUsage()
                    memoryReadings.append(currentMemory)
                    lastMemory = currentMemory

                    // Simulate memory warning at midpoint
                    if i == 10 {
                        NotificationCenter.default.post(
                            name: UIApplication.didReceiveMemoryWarningNotification,
                            object: nil
                        )
                    }
                }
            }
        }

        // Verify memory pressure handling
        let peakMemory = memoryReadings.max() ?? 0
        let finalMemory = getMemoryUsage()

        XCTAssertLessThan(peakMemory - lastMemory, maxMemoryLimit, "Peak memory should not exceed limit")
        XCTAssertLessThan(finalMemory - lastMemory, maxMemoryLimit / 2, "Should recover from memory pressure")

        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)
    }

    func testConcurrentBufferOperations() {
        let expectation = XCTestExpectation(description: "Concurrent operations")
        let operationCount = 50
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        var successfulOperations = 0
        var failedOperations = 0
        let initialMemory = getMemoryUsage()
        var peakMemory = initialMemory

        // Perform concurrent operations
        for _ in 0 ..< operationCount {
            group.enter()
            concurrentQueue.async {
                autoreleasepool {
                    if let buffer = self.createTestBuffer(duration: 0.5) {
                        // Process buffer
                        self.audioProcessor.processAudioBuffer(buffer) { _ in }
                        successfulOperations += 1

                        // Track memory
                        let currentMemory = self.getMemoryUsage()
                        peakMemory = max(peakMemory, currentMemory)
                    } else {
                        failedOperations += 1
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            // Verify results
            XCTAssertGreaterThan(successfulOperations, 0, "Should complete some operations")
            XCTAssertLessThan(failedOperations, operationCount / 2, "Should not fail too many operations")
            XCTAssertLessThan(peakMemory - initialMemory, self.maxMemoryLimit, "Should stay under memory limit")

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testBufferLifecycleManagement() {
        let expectation = XCTestExpectation(description: "Buffer lifecycle")
        let bufferCount = 10
        var buffers: [ManagedAudioBuffer] = []

        // Allocate buffers
        for _ in 0 ..< bufferCount {
            if let buffer = audioBufferPool.getBuffer() {
                buffers.append(buffer)
            }
        }

        XCTAssertEqual(buffers.count, bufferCount, "Should allocate all requested buffers")

        // Use buffers
        for buffer in buffers {
            // Mark as used
            buffer.markUsed()
            XCTAssertLessThan(buffer.idleTime, 0.1, "Buffer should not be idle after use")
        }

        // Return half the buffers
        for _ in 0 ..< bufferCount / 2 {
            if let buffer = buffers.popLast() {
                audioBufferPool.returnBuffer(buffer)
            }
        }

        // Try to get new buffers
        var newBuffers: [ManagedAudioBuffer] = []
        for _ in 0 ..< bufferCount / 2 {
            if let buffer = audioBufferPool.getBuffer() {
                newBuffers.append(buffer)
            }
        }

        XCTAssertEqual(newBuffers.count, bufferCount / 2, "Should reuse returned buffers")

        // Cleanup
        buffers.forEach { audioBufferPool.returnBuffer($0) }
        newBuffers.forEach { audioBufferPool.returnBuffer($0) }

        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Helper Methods

    private func createTestBuffer(duration: TimeInterval) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(duration * testSampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: testSampleRate, channels: 2)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount

        // Fill with test signal
        if let channelData = buffer.floatChannelData {
            for channel in 0 ..< Int(format.channelCount) {
                for frame in 0 ..< Int(frameCount) {
                    let phase = 2.0 * .pi * 440.0 * Double(frame) / testSampleRate
                    channelData[channel][frame] = Float(sin(phase))
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
