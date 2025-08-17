import CoreData
import Foundation

/// Errors that can occur in the application
public enum AppError: LocalizedError {
    case audioLoadFailed(Error)
    case deletionFailure(Error)
    case saveFailure(Error)
    case aiServiceUnavailable
    case resourcesUnavailable
    case serviceUnavailable
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case let .audioLoadFailed(error):
            "Failed to load audio: \(error.localizedDescription)"
        case let .deletionFailure(error):
            "Failed to delete item: \(error.localizedDescription)"
        case let .saveFailure(error):
            "Failed to save changes: \(error.localizedDescription)"
        case .aiServiceUnavailable:
            "AI service is temporarily unavailable"
        case .resourcesUnavailable:
            "Required resources are not available"
        case .serviceUnavailable:
            "Service is temporarily unavailable"
        case let .unknown(error):
            "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

/// Protocol for objects that can handle errors
public protocol ErrorHandling {
    func handle(_ error: AppError, in context: String)
    func clearErrors()
}

/// Default error handler implementation
public class ErrorCoordinator: ErrorHandling {
    private var errors: [String: [AppError]] = [:]

    public init() {}

    public func handle(_ error: AppError, in context: String) {
        if errors[context] == nil {
            errors[context] = []
        }
        errors[context]?.append(error)
    }

    public func clearErrors() {
        errors.removeAll()
    }
}
