import Foundation
import Accelerate

public enum DSP {
    /// Compute root-mean-square of a float buffer.
    /// - Parameter samples: Array of Float samples.
    /// - Returns: RMS value (>= 0). Returns 0 for empty input.
    /// - Note: Handles large buffers efficiently and validates input ranges.
    public static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        
        // Input validation for audio samples
        let validSamples = samples.compactMap { sample -> Float? in
            guard sample.isFinite else { return nil }
            return sample.clamped(to: -1.0...1.0)
        }
        
        guard !validSamples.isEmpty else { return 0 }
        
        var result: Float = 0
        validSamples.withUnsafeBufferPointer { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            vDSP_rmsqv(baseAddress, 1, &result, vDSP_Length(validSamples.count))
        }
        
        return result.isFinite ? result : 0
    }
    
    /// Compute RMS for large audio buffers using chunking for memory efficiency.
    /// - Parameters:
    ///   - samples: Array of Float samples
    ///   - chunkSize: Size of each processing chunk (default: 4096)
    /// - Returns: RMS value (>= 0)
    public static func rmsLargeBuffer(_ samples: [Float], chunkSize: Int = 4096) -> Float {
        guard !samples.isEmpty else { return 0 }
        
        let chunks = samples.chunked(into: chunkSize)
        let chunkRMS = chunks.compactMap { chunk -> Float? in
            let rmsValue = rms(chunk)
            return rmsValue > 0 ? rmsValue * rmsValue : nil
        }
        
        guard !chunkRMS.isEmpty else { return 0 }
        
        let meanSquare = chunkRMS.reduce(0, +) / Float(chunkRMS.count)
        return sqrt(meanSquare)
    }
}

// MARK: - Private Extensions
private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
