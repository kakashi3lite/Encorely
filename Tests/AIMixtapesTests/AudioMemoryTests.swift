import XCTest
@testable import AIMixtapes

final class AudioMemoryTests: XCTestCase {
    private var audioProcessor: AudioProcessor!
    private let maxMemoryLimit = 50 * 1024 * 1024 // 50MB
    private let testSampleRate: Double = 44100
    
    override func setUp() {
        super.setUp()
        audioProcessor = AudioProcessor()
    }
    
    override func tearDown() {
        audioProcessor = nil
        super.tearDown()
    }
    
    func testBufferPoolMemoryManagement() throws {
        let initialMemory = getMemoryUsage()
        let duration: TimeInterval = 2.0
        var buffers: [ManagedAudioBuffer] = []
        
        // Create buffers until memory pressure
        while getMemoryUsage() - initialMemory < maxMemoryLimit {
            let buffer = createTestBuffer(duration: duration)
            let managedBuffer = ManagedAudioBuffer(buffer: buffer)
            buffers.append(managedBuffer)
            autoreleasepool {
                // Process each buffer
                audioProcessor.handleAudioData(buffer: buffer)
            }
        }
        
        // Memory should be near but not over limit
        let usedMemory = getMemoryUsage() - initialMemory
        XCTAssertLessThan(usedMemory, maxMemoryLimit, "Memory usage exceeded limit")
        XCTAssertGreaterThan(usedMemory, maxMemoryLimit/2, "Memory usage unusually low")
        
        // Clear buffers
        buffers.removeAll()
        audioProcessor.cleanupBuffers()
        
        // Memory should be significantly reduced
        let finalMemory = getMemoryUsage() - initialMemory 
        XCTAssertLessThan(finalMemory, maxMemoryLimit/4, "Memory not properly released")
    }
    
    func testMemoryPressureHandling() {
        let initialMemory = getMemoryUsage()
        var lastMemory = initialMemory
        
        // Create memory pressure
        for i in 0..<20 {
            autoreleasepool {
                let buffer = createTestBuffer(duration: 1.0)
                audioProcessor.handleAudioData(buffer: buffer)
                
                let currentMemory = getMemoryUsage()
                if i > 0 {
                    // Memory increase should slow down under pressure
                    let increase = currentMemory - lastMemory
                    XCTAssertLessThan(increase, maxMemoryLimit/10, "Memory growing too fast")
                }
                lastMemory = currentMemory
            }
        }
        
        // Final memory should be under limit
        let finalMemory = getMemoryUsage()
        XCTAssertLessThan(finalMemory - initialMemory, maxMemoryLimit, 
                         "Memory pressure not properly handled")
    }
    
    func testConcurrentBufferProcessing() {
        let concurrentCount = 5
        let expectation = XCTestExpectation(description: "Concurrent processing")
        expectation.expectedFulfillmentCount = concurrentCount
        
        let initialMemory = getMemoryUsage()
        
        // Process buffers concurrently
        for _ in 0..<concurrentCount {
            DispatchQueue.global().async {
                autoreleasepool {
                    let buffer = self.createTestBuffer(duration: 0.5)
                    self.audioProcessor.handleAudioData(buffer: buffer)
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 10)
        
        // Check memory hasn't grown excessively
        let finalMemory = getMemoryUsage()
        XCTAssertLessThan(finalMemory - initialMemory, maxMemoryLimit/2,
                         "Concurrent processing caused excessive memory growth")
    }
    
    // MARK: - Helper Methods
    
    private func createTestBuffer(duration: TimeInterval) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * testSampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: testSampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        
        buffer.frameLength = frameCount
        if let channelData = buffer.floatChannelData?[0] {
            // Fill with test signal
            for i in 0..<Int(frameCount) {
                let frequency = 440.0 // A4 note
                let amplitude = 0.5
                channelData[i] = Float(amplitude * sin(2.0 * .pi * frequency * Double(i) / testSampleRate))
            }
        }
        
        return buffer
    }
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}
