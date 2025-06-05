import Foundation

enum AudioProcessingError: LocalizedError {
    case invalidBuffer
    case processingFailed(String)
    case memoryLimitExceeded
    case bufferPoolExhausted
    case invalidFormat
    case analysisTimeout
    case engineNotRunning
    
    var errorDescription: String? {
        switch self {
        case .invalidBuffer:
            return "Invalid audio buffer provided"
        case .processingFailed(let reason):
            return "Audio processing failed: \(reason)"
        case .memoryLimitExceeded:
            return "Memory usage exceeded maximum limit"
        case .bufferPoolExhausted:
            return "Audio buffer pool exhausted"
        case .invalidFormat:
            return "Invalid audio format"
        case .analysisTimeout:
            return "Audio analysis timed out"
        case .engineNotRunning:
            return "Audio engine is not running"
        }
    }
}