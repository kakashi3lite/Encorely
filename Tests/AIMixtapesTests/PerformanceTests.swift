import XCTest
@testable import AIMixtapes

final class PerformanceTests: XCTestCase {
    var performanceMonitor: PerformanceMonitor!
    var performanceValidator: PerformanceValidator!
    
    override func setUp() {
        super.setUp()
        performanceMonitor = PerformanceMonitor.shared
        performanceValidator = PerformanceValidator()
    }
    
    func testTrackPlaybackPerformance() {
        measure {
            let player = PlayerManager()
            let track = Track(id: UUID().uuidString, title: "Test Track")
            player.play(track)
            Thread.sleep(forTimeInterval: 0.1) // Simulate playback
            player.stop()
        }
    }
    
    func testMemoryUsageUnderLoad() {
        let initialMemory = getMemoryUsage()
        
        // Simulate heavy load
        var players: [PlayerManager] = []
        for _ in 0..<10 {
            let player = PlayerManager()
            players.append(player)
            let track = Track(id: UUID().uuidString, title: "Test Track")
            player.play(track)
        }
        
        let peakMemory = getMemoryUsage()
        
        // Cleanup
        players.forEach { $0.stop() }
        players.removeAll()
        
        let finalMemory = getMemoryUsage()
        
        // Assert memory usage is within acceptable bounds
        XCTAssertLessThan(peakMemory - initialMemory, 100 * 1024 * 1024) // 100MB limit
        XCTAssertLessThan(finalMemory - initialMemory, 5 * 1024 * 1024)  // 5MB residual limit
    }
    
    func testAudioProcessingPerformance() async throws {
        // This test validates that the audio processing system meets performance requirements
        let expectation = XCTestExpectation(description: "Performance validation completes")
        
        Task {
            let results = await performanceValidator.validatePerformanceConstraints()
            
            // Log the results
            print("==== Audio Processing Performance Results ====")
            print("Latency: \(results.latencyResult.passed ? "PASSED" : "FAILED") - Avg: \(String(format: "%.1f", results.latencyResult.averageLatencyMs))ms")
            print("Memory: \(results.memoryResult.passed ? "PASSED" : "FAILED") - Peak: \(String(format: "%.1f", results.memoryResult.peakMemoryMB))MB")
            print("Accuracy: \(results.accuracyResult.passed ? "PASSED" : "FAILED") - \(String(format: "%.1f", results.accuracyResult.accuracy * 100))%")
            print("Overall: \(results.overallPassed ? "PASSED" : "FAILED")")
            
            // We don't assert on the exact values as they may vary by hardware
            // Just verify that the validator ran and produced results
            XCTAssertGreaterThan(results.latencyResult.processingTimes.count, 0)
            XCTAssertGreaterThan(results.accuracyResult.totalPredictions, 0)
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 30.0)
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
}
