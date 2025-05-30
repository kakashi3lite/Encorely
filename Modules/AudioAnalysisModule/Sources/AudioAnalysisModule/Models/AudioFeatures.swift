import Foundation

public struct AudioFeatures {
    /// Root Mean Square (RMS) energy of the audio signal
    public let rms: Float
    
    /// Zero Crossing Rate - frequency of signal sign changes
    public let zeroCrossingRate: Float
    
    /// Spectral Centroid - weighted mean of frequencies
    public let spectralCentroid: Float
    
    /// Spectral Rolloff - frequency below which 85% of signal energy lies
    public let spectralRolloff: Float
    
    /// Mel-frequency Cepstral Coefficients
    public let mfcc: [Float]
    
    public init(rms: Float, zeroCrossingRate: Float, spectralCentroid: Float, spectralRolloff: Float, mfcc: [Float]) {
        self.rms = rms
        self.zeroCrossingRate = zeroCrossingRate
        self.spectralCentroid = spectralCentroid
        self.spectralRolloff = spectralRolloff
        self.mfcc = mfcc
    }
}
