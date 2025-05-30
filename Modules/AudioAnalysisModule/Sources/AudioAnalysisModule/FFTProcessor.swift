import Foundation
import Accelerate

public class FFTProcessor {
    private let fftSetup: vDSP_DFT_Setup
    private let log2n: UInt
    private let n: UInt
    
    public init?(size: Int) {
        guard let log2n = UInt(exactly: log2(Double(size))) else { return nil }
        self.log2n = log2n
        self.n = UInt(size)
        
        guard let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(size), vDSP_DFT_FORWARD) else {
            return nil
        }
        self.fftSetup = setup
    }
    
    deinit {
        vDSP_DFT_DestroySetup(fftSetup)
    }
    
    public func performFFT(on samples: [Float]) -> [Float] {
        var realIn = [Float](repeating: 0.0, count: Int(n))
        var imagIn = [Float](repeating: 0.0, count: Int(n))
        var realOut = [Float](repeating: 0.0, count: Int(n))
        var imagOut = [Float](repeating: 0.0, count: Int(n))
        
        // Copy input samples
        realIn.replaceSubrange(0..<min(samples.count, Int(n)), with: samples[0..<min(samples.count, Int(n))])
        
        // Apply Hanning window
        var window = [Float](repeating: 0.0, count: Int(n))
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        vDSP_vmul(realIn, 1, window, 1, &realIn, 1, vDSP_Length(n))
        
        // Perform FFT
        vDSP_DFT_Execute(fftSetup,
                        realIn.withUnsafeBufferPointer { $0.baseAddress! },
                        imagIn.withUnsafeBufferPointer { $0.baseAddress! },
                        realOut.withUnsafeBufferPointer { $0.baseAddress! },
                        imagOut.withUnsafeBufferPointer { $0.baseAddress! })
        
        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0.0, count: Int(n))
        vDSP_zvmags(&realOut, 1, &magnitudes, 1, vDSP_Length(n/2))
        
        // Convert to dB scale
        var scaledMagnitudes = [Float](repeating: 0.0, count: Int(n/2))
        var zero: Float = 1e-6 // To avoid log of zero
        vDSP_vdbcon(magnitudes, 1, &zero, &scaledMagnitudes, 1, vDSP_Length(n/2), 1)
        
        return scaledMagnitudes
    }
}
