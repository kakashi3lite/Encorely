import AVFoundation
import Foundation
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
        case let .fileNotFound(url):
            "Audio file not found at: \(url.lastPathComponent)"
        case let .invalidFormat(details):
            "Invalid audio format: \(details)"
        case let .processingFailed(reason):
            "Audio processing failed: \(reason)"
        case .bufferCreationFailed:
            "Failed to create audio buffer"
        case let .memoryPressure(details):
            "Memory pressure detected: \(details)"
        case let .resourceBusy(resource):
            "Resource is busy: \(resource)"
        case let .timeout(operation):
            "Operation timed out: \(operation)"
        case let .engineStartFailed(reason):
            "Failed to start audio engine: \(reason)"
        case .permissionDenied:
            "Audio permission denied"
        case .cancelled:
            "Operation cancelled"
        case let .unknown(error):
            "Unknown error: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            "Please verify the file exists and you have permission to access it."
        case .invalidFormat:
            "Try converting the file to a supported format (e.g., WAV or AAC)."
        case .processingFailed:
            "Try reducing the audio file size or closing other applications."
        case .bufferCreationFailed:
            "Free up memory by closing other applications."
        case .memoryPressure:
            "Close other applications to free up memory."
        case .resourceBusy:
            "Wait a few moments and try again."
        case .timeout:
            "Check your device's performance and try again."
        case .engineStartFailed:
            "Restart the application or check audio settings."
        case .permissionDenied:
            "Grant audio permission in Settings."
        case .cancelled:
            "Try the operation again."
        case .unknown:
            "Restart the application and try again."
        }
    }

    var recoveryOptions: [String] {
        switch self {
        case .memoryPressure:
            ["Free Memory", "Reduce Quality", "Cancel"]
        case .resourceBusy:
            ["Wait", "Force Stop", "Cancel"]
        case .permissionDenied:
            ["Open Settings", "Cancel"]
        default:
            ["Try Again", "Cancel"]
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
        """)
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
            true
        default:
            false
        }
    }

    var error: AudioProcessingError? {
        switch self {
        case let .failure(error), let .partial(_, error):
            error
        default:
            nil
        }
    }

    var value: T? {
        switch self {
        case let .success(value), let .partial(value, _):
            value
        default:
            nil
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
                true
            default:
                false
            }
        }
    )
}
