import Foundation

enum AudioProcessingError: Error {
    case fftSetupFailed
    case invalidBufferFormat
    case processingFailed
}
