import XCTest
@testable import AIMixtapes

final class PerformanceTests: XCTestCase {
    var performanceMonitor: PerformanceMonitor!
    
    override func setUp() {
        super.setUp()
        performanceMonitor = PerformanceMonitor.shared
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
