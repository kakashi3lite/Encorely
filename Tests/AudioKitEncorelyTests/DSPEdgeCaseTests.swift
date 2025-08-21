import XCTest
@testable import AudioKitEncorely

final class DSPEdgeCaseTests: XCTestCase {
    func testRMSWithInfiniteValues() {
        let samples: [Float] = [0.5, .infinity, 0.3, -.infinity, 0.1]
        let result = DSP.rms(samples)
        
        // Should handle infinite values gracefully
        XCTAssertTrue(result.isFinite)
        XCTAssertGreaterThan(result, 0)
    }
    
    func testRMSWithNaNValues() {
        let samples: [Float] = [0.5, .nan, 0.3, .nan, 0.1]
        let result = DSP.rms(samples)
        
        // Should handle NaN values gracefully
        XCTAssertTrue(result.isFinite)
        XCTAssertGreaterThan(result, 0)
    }
    
    func testRMSWithOutOfRangeValues() {
        let samples: [Float] = [-2.0, 1.5, -1.5, 2.0, 0.5]
        let result = DSP.rms(samples)
        
        // Should clamp values to [-1.0, 1.0] range
        XCTAssertTrue(result.isFinite)
        XCTAssertGreaterThan(result, 0)
        XCTAssertLessThanOrEqual(result, 1.0)
    }
    
    func testRMSLargeBuffer() {
        let samples = Array(repeating: Float(0.5), count: 10000)
        let result = DSP.rmsLargeBuffer(samples)
        
        XCTAssertEqual(result, 0.5, accuracy: 1e-6)
    }
    
    func testRMSLargeBufferEmpty() {
        let samples: [Float] = []
        let result = DSP.rmsLargeBuffer(samples)
        
        XCTAssertEqual(result, 0)
    }
    
    func testRMSAllInvalidSamples() {
        let samples: [Float] = [.nan, .infinity, -.infinity]
        let result = DSP.rms(samples)
        
        XCTAssertEqual(result, 0)
    }
}