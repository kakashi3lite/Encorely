import Accelerate
import Foundation

/// Digital Signal Processing utilities
public enum DSP {
    /// Compute root-mean-square of a float buffer.
    /// - Parameter samples: Array of Float samples.
    /// - Returns: RMS value (>= 0). Returns 0 for empty input.
    public static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var result: Float = 0
        samples.withUnsafeBufferPointer { ptr in
            if let baseAddress = ptr.baseAddress {
                vDSP_rmsqv(baseAddress, 1, &result, vDSP_Length(samples.count))
            }
        }
        return result
    }
}
