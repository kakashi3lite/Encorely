import Foundation

/// Represents the extracted spectral features from an audio frame
struct SpectralFeatures {
    // Core spectral features
    var centroid: Float = 0
    var spread: Float = 0
    var rolloff: Float = 0
    var flatness: Float = 0
    var flux: Float = 0
    
    // Band energy distribution
    var bassEnergy: Float = 0
    var midEnergy: Float = 0
    var trebleEnergy: Float = 0
    
    // MFCC coefficients
    var mfcc: [Float] = []
    
    // Rhythmic features
    var estimatedTempo: Float = 0
}
