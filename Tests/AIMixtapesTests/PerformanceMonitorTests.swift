import XCTest
@testable import AIMixtapes

final class PerformanceMonitorTests: XCTestCase {
    var performanceMonitor: PerformanceMonitor!
    
    override func setUp() {
        super.setUp()
        performanceMonitor = PerformanceMonitor.shared
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testMetricsTracking() {
        let identifier = "test_operation"
        
        performanceMonitor.startTracking(identifier)
        Thread.sleep(forTimeInterval: 0.1) // Simulate work
        performanceMonitor.endTracking(identifier)
        
        // Add another measurement
        performanceMonitor.startTracking(identifier)
        Thread.sleep(forTimeInterval: 0.1) // Simulate work
        performanceMonitor.endTracking(identifier)
    }
    
    func testMemoryReporting() {
        performanceMonitor.reportMemoryUsage()
        // Should complete without error
    }
    
    func testCPUUsageTracking() {
        // Create some CPU load
        DispatchQueue.global().async {
            for _ in 0..<1000000 {
                _ = sin(Double.random(in: 0...1))
            }
        }
        
        Thread.sleep(forTimeInterval: 0.5)
        performanceMonitor.reportCPUUsage()
    }
    
    func testDiskUsageReporting() {
        // Create temporary file
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_file")
        let testData = Data(repeating: 0, count: 1024 * 1024) // 1MB
        
        try? testData.write(to: tempFileURL)
        performanceMonitor.reportDiskUsage()
        
        try? FileManager.default.removeItem(at: tempFileURL)
    }
    
    func testMultipleOperationsTracking() {
        let operations = ["op1", "op2", "op3"]
        
        for op in operations {
            performanceMonitor.startTracking(op)
            Thread.sleep(forTimeInterval: 0.05)
            performanceMonitor.endTracking(op)
        }
    }
    
    func testConcurrentOperationsTracking() {
        let queue = DispatchQueue.global()
        let group = DispatchGroup()
        
        for i in 0..<5 {
            group.enter()
            queue.async {
                let identifier = "concurrent_op_\(i)"
                self.performanceMonitor.startTracking(identifier)
                Thread.sleep(forTimeInterval: Double.random(in: 0.1...0.3))
                self.performanceMonitor.endTracking(identifier)
                group.leave()
            }
        }
        
        group.wait()
    }
    
    func testMemoryWarningHandling() {
        let expectation = XCTestExpectation(description: "Memory warning handled")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .performanceMemoryWarning,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        // Simulate memory warning
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
    
    // Performance Tests
    func testTrackingPerformance() {
        measure {
            for i in 0..<100 {
                let identifier = "perf_test_\(i)"
                performanceMonitor.startTracking(identifier)
                performanceMonitor.endTracking(identifier)
            }
        }
    }
    
    func testMemoryReportingPerformance() {
        measure {
            for _ in 0..<10 {
                performanceMonitor.reportMemoryUsage()
            }
        }
    }
    
    func testCPUReportingPerformance() {
        measure {
            for _ in 0..<10 {
                performanceMonitor.reportCPUUsage()
            }
        }
    }
}

// MARK: - Test Helpers
extension PerformanceMonitor {
    func reportCPUUsage() {
        // Making the private method accessible for testing
        if let mirror = Mirror(reflecting: self).children.first(where: { $0.label == "reportCPUUsage" }) {
            if let method = mirror.value as? () -> Void {
                method()
            }
        }
    }
}
