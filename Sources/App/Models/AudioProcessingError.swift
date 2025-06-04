import Foundation
import AVFoundation
import os.log

/// Comprehensive error handling for audio processing
enum AudioProcessingError: LocalizedError {
    case fileNotFound(URL)
    case invalidFormat(String)
    case processingFailed(String)
    case bufferCreationFailed
    case memoryPressure(String)
    case resourceBusy(String)
    case timeout(String)
    case engineStartFailed(String)
    case permissionDenied
    case cancelled
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Audio file not found at: \(url.lastPathComponent)"
        case .invalidFormat(let details):
            return "Invalid audio format: \(details)"
        case .processingFailed(let reason):
            return "Audio processing failed: \(reason)"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .memoryPressure(let details):
            return "Memory pressure detected: \(details)"
        case .resourceBusy(let resource):
            return "Resource is busy: \(resource)"
        case .timeout(let operation):
            return "Operation timed out: \(operation)"
        case .engineStartFailed(let reason):
            return "Failed to start audio engine: \(reason)"
        case .permissionDenied:
            return "Audio permission denied"
        case .cancelled:
            return "Operation cancelled"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Please verify the file exists and you have permission to access it."
        case .invalidFormat:
            return "Try converting the file to a supported format (e.g., WAV or AAC)."
        case .processingFailed:
            return "Try reducing the audio file size or closing other applications."
        case .bufferCreationFailed:
            return "Free up memory by closing other applications."
        case .memoryPressure:
            return "Close other applications to free up memory."
        case .resourceBusy:
            return "Wait a few moments and try again."
        case .timeout:
            return "Check your device's performance and try again."
        case .engineStartFailed:
            return "Restart the application or check audio settings."
        case .permissionDenied:
            return "Grant audio permission in Settings."
        case .cancelled:
            return "Try the operation again."
        case .unknown:
            return "Restart the application and try again."
        }
    }
    
    var recoveryOptions: [String] {
        switch self {
        case .memoryPressure:
            return ["Free Memory", "Reduce Quality", "Cancel"]
        case .resourceBusy:
            return ["Wait", "Force Stop", "Cancel"]
        case .permissionDenied:
            return ["Open Settings", "Cancel"]
        default:
            return ["Try Again", "Cancel"]
        }
    }
}

/// Protocol for handling audio processing errors
protocol AudioErrorHandler: AnyObject {
    func handleError(_ error: AudioProcessingError)
    func handleWarning(_ message: String)
    func logError(_ error: AudioProcessingError, file: String, function: String, line: Int)
}

/// Default implementation of audio error handling
class DefaultAudioErrorHandler: AudioErrorHandler {
    private let logger = Logger(subsystem: "com.aimixtapes", category: "AudioErrorHandler")
    
    func handleError(_ error: AudioProcessingError) {
        logger.error("\(error.localizedDescription)")
        
        switch error {
        case .memoryPressure:
            NotificationCenter.default.post(name: .audioMemoryPressureWarning, object: error)
        case .resourceBusy:
            NotificationCenter.default.post(name: .audioResourceBusyWarning, object: error)
        case .permissionDenied:
            NotificationCenter.default.post(name: .audioPermissionDenied, object: error)
        default:
            NotificationCenter.default.post(name: .audioProcessingError, object: error)
        }
    }
    
    func handleWarning(_ message: String) {
        logger.warning("\(message)")
        NotificationCenter.default.post(name: .audioProcessingWarning, object: message)
    }
    
    func logError(_ error: AudioProcessingError, file: String, function: String, line: Int) {
        logger.error("""
            Error: \(error.localizedDescription)
            File: \(file)
            Function: \(function)
            Line: \(line)
            Recovery suggestion: \(error.recoverySuggestion ?? "None")
            """
        )
    }
}

// Notification names for error handling
extension Notification.Name {
    static let audioProcessingError = Notification.Name("AudioProcessingError")
    static let audioProcessingWarning = Notification.Name("AudioProcessingWarning")
    static let audioMemoryPressureWarning = Notification.Name("AudioMemoryPressureWarning")
    static let audioResourceBusyWarning = Notification.Name("AudioResourceBusyWarning")
    static let audioPermissionDenied = Notification.Name("AudioPermissionDenied")
}

/// Result type for audio processing operations
enum AudioProcessingResult<T> {
    case success(T)
    case failure(AudioProcessingError)
    case partial(T, AudioProcessingError)
    
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        default:
            return false
        }
    }
    
    var error: AudioProcessingError? {
        switch self {
        case .failure(let error), .partial(_, let error):
            return error
        default:
            return nil
        }
    }
    
    var value: T? {
        switch self {
        case .success(let value), .partial(let value, _):
            return value
        default:
            return nil
        }
    }
}

/// Retry configuration for audio operations
struct RetryConfig {
    let maxAttempts: Int
    let delay: TimeInterval
    let shouldRetry: (AudioProcessingError) -> Bool
    
    static let `default` = RetryConfig(
        maxAttempts: 3,
        delay: 1.0,
        shouldRetry: { error in
            switch error {
            case .memoryPressure, .resourceBusy, .timeout:
                return true
            default:
                return false
            }
        }
    )
}
