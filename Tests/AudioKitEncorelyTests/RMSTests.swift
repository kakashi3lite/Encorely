import XCTest
@testable import AudioKitEncorely

final class RMSTests: XCTestCase {
    func testRMSConstantSignal() {
        let n = 1024
        let amplitude: Float = 0.5
        let samples = Array(repeating: amplitude, count: n)
        let value = DSP.rms(samples)
        XCTAssertEqual(value, amplitude, accuracy: 1e-6)
    }

    func testRMSEmpty() {
        let samples: [Float] = []
        let value = DSP.rms(samples)
        XCTAssertEqual(value, 0)
    }
}
