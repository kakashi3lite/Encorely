@testable import App
import XCTest

final class AudioMemoryPerformanceTests: XCTestCase {
    private var audioBufferPool: AudioBufferPool!
    private var format: AVAudioFormat!
    private let testSampleRate: Double = 44100
    private let maxMemoryLimit = 50 * 1024 * 1024 // 50MB

    override func setUp() {
        super.setUp()
        format = AVAudioFormat(standardFormatWithSampleRate: testSampleRate, channels: 2)!
        audioBufferPool = AudioBufferPool(format: format, frameCapacity: 4096)
    }

    override func tearDown() {
        audioBufferPool = nil
        super.tearDown()
    }

    // MARK: - Tests

    func testBufferAllocationAndReuse() {
        let expectation = XCTestExpectation(description: "Buffer allocation and reuse")
        let initialMemory = getMemoryUsage()
        let operationCount = 1000
        var allocatedBuffers: [ManagedAudioBuffer] = []

        // Perform rapid buffer allocations
        for _ in 0 ..< operationCount {
            if let buffer = audioBufferPool.getBuffer() {
                allocatedBuffers.append(buffer)

                // Return some buffers immediately to test reuse
                if allocatedBuffers.count % 3 == 0 {
                    audioBufferPool.returnBuffer(allocatedBuffers.removeLast())
                }
            }
        }

        // Check memory usage
        let peakMemory = getMemoryUsage()
        XCTAssertLessThan(peakMemory - initialMemory, maxMemoryLimit, "Memory usage exceeded limit")

        // Return all buffers
        allocatedBuffers.forEach { audioBufferPool.returnBuffer($0) }

        // Wait for cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let finalMemory = self.getMemoryUsage()
            XCTAssertLessThan(finalMemory - initialMemory, self.maxMemoryLimit / 4, "Memory not properly released")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testMemoryPressureHandling() {
        let expectation = XCTestExpectation(description: "Memory pressure handling")
        var buffers: [ManagedAudioBuffer] = []
        let initialMemory = getMemoryUsage()

        // Create memory pressure
        while getMemoryUsage() - initialMemory < maxMemoryLimit * 3 / 4 {
            if let buffer = audioBufferPool.getBuffer() {
                buffers.append(buffer)
            }
        }

        // Simulate memory warning
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)

        // Wait for cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let midMemory = self.getMemoryUsage()
            XCTAssertLessThan(midMemory - initialMemory, self.maxMemoryLimit / 2, "Memory not released after warning")

            // Return remaining buffers
            buffers.forEach { self.audioBufferPool.returnBuffer($0) }
            buffers.removeAll()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let finalMemory = self.getMemoryUsage()
                XCTAssertLessThan(finalMemory - initialMemory, self.maxMemoryLimit / 4, "Final cleanup ineffective")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testConcurrentBufferOperations() {
        let expectation = XCTestExpectation(description: "Concurrent operations")
        let operationCount = 100
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()

        var peakMemory = 0
        let initialMemory = getMemoryUsage()

        // Perform concurrent operations
        for _ in 0 ..< operationCount {
            group.enter()
            concurrentQueue.async {
                autoreleasepool {
                    if let buffer = self.audioBufferPool.getBuffer() {
                        // Hold buffer briefly
                        Thread.sleep(forTimeInterval: 0.01)
                        self.audioBufferPool.returnBuffer(buffer)

                        let currentMemory = self.getMemoryUsage()
                        peakMemory = max(peakMemory, currentMemory)
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            XCTAssertLessThan(
                peakMemory - initialMemory,
                self.maxMemoryLimit,
                "Concurrent operations exceeded memory limit"
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testBufferLifecycleManagement() {
        let expectation = XCTestExpectation(description: "Buffer lifecycle")
        let initialMemory = getMemoryUsage()
        var buffers: [ManagedAudioBuffer] = []

        // Allocate buffers with different usage patterns
        for i in 0 ..< 20 {
            if let buffer = audioBufferPool.getBuffer() {
                buffers.append(buffer)

                // Simulate different usage patterns
                if i % 3 == 0 {
                    // Frequently used buffer
                    for _ in 0 ..< 5 {
                        audioBufferPool.returnBuffer(buffer)
                        if let reusedBuffer = audioBufferPool.getBuffer() {
                            buffers.append(reusedBuffer)
                        }
                    }
                }
            }
        }

        // Let some buffers age
        Thread.sleep(forTimeInterval: 2.0)

        // Return all buffers
        buffers.forEach { audioBufferPool.returnBuffer($0) }
        buffers.removeAll()

        // Wait for cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let finalMemory = self.getMemoryUsage()
            XCTAssertLessThan(finalMemory - initialMemory, self.maxMemoryLimit / 4, "Memory not properly managed")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Helpers

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
