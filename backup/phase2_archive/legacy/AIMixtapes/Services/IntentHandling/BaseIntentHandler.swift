import Combine
import Foundation
import Intents

protocol BaseIntentHandler {
    var processingTimeout: TimeInterval { get }
    var intentQueue: DispatchQueue { get }
    var retryCount: Int { get }
    var retryDelay: TimeInterval { get }
    var recoveryOptions: [IntentRecoveryOption] { get }
}

extension BaseIntentHandler {
    // Default values
    var processingTimeout: TimeInterval { 2.0 }
    var intentQueue: DispatchQueue {
        DispatchQueue(label: "com.aimixtapes.intent-handling", qos: .userInitiated)
    }

    var retryCount: Int { 2 }
    var retryDelay: TimeInterval { 0.5 }

    func handleWithTimeout<T>(_ operation: @escaping () -> AnyPublisher<T, Error>) -> Future<T, Error> {
        Future { promise in
            var attempts = 0

            func attempt() {
                operation()
                    .timeout(self.processingTimeout, scheduler: self.intentQueue)
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case let .failure(error):
                                if attempts < self.retryCount {
                                    attempts += 1
                                    self.intentQueue.asyncAfter(deadline: .now() + self.retryDelay) {
                                        attempt()
                                    }
                                } else {
                                    promise(.failure(error))
                                }
                            }
                        },
                        receiveValue: { value in
                            promise(.success(value))
                        }
                    )
                    .store(in: &self.cancellables)
            }

            attempt()
        }
    }

    /// Validates intent parameters and returns a result
    func validateParameters(_ intent: some INIntent,
                            validations: [(String, Any?) -> Bool]) -> Result<Void, IntentError>
    {
        for validation in validations {
            let mirror = Mirror(reflecting: intent)
            for child in mirror.children {
                if let result = validation(child.label ?? "", child.value), !result {
                    return .failure(.invalidParameters)
                }
            }
        }
        return .success(())
    }
}

// Intent specific errors
enum IntentError: LocalizedError {
    case invalidParameters
    case processingTimeout
    case serviceUnavailable
    case recoveryFailed

    var errorDescription: String? {
        switch self {
        case .invalidParameters:
            "Invalid parameters provided"
        case .processingTimeout:
            "Request timed out"
        case .serviceUnavailable:
            "Service temporarily unavailable"
        case .recoveryFailed:
            "Failed to recover from error"
        }
    }
}

// Custom recovery options
struct IntentRecoveryOption {
    let title: String
    let action: () -> Void
}

private var cancellables = Set<AnyCancellable>()
