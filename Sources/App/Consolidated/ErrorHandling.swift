import AVFoundation
import Combine
import CoreData
import Foundation
import SwiftUI
import os.log
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Central error handling system for AI-Mixtapes
enum AppError: LocalizedError {
    // App-level errors
    case invalidConfiguration
    case missingPermissions(String)
    case userCancelled

    // Audio-related errors
    case audioLoadFailed(Error?)
    case audioProcessingFailed(Error?)
    case audioUnavailable
    case unsupportedAudioFormat
    case audioBufferOverflow
    case audioSessionInterrupted

    // AI-related errors
    case aiServiceUnavailable
    case modelLoadFailed
    case inferenceError
    case insufficientData
    case modelNotReady
    case maxRetriesExceeded
    case aiGenerationFailed(Error)
    case aiAnalysisFailed(Error)
    case songFetchFailed(Error)
    case modelDownloadFailed(Error)
    case aiPredictionFailed(Error)
    case invalidPrediction
    case decodingFailed(Error)

    // CoreData errors
    case saveFailure(Error)
    case fetchFailure(Error)
    case deletionFailure(Error)
    case mergeConflict(Error)

    // Resource errors
    case lowMemory
    case diskSpaceLow
    case networkUnavailable
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "Invalid app configuration"
        case let .missingPermissions(permission):
            "Missing permission: \(permission)"
        case .userCancelled:
            "Operation cancelled by user"
        case let .audioLoadFailed(error):
            "Failed to load audio: \(error?.localizedDescription ?? "Unknown error")"
        case let .audioProcessingFailed(error):
            "Audio processing failed: \(error?.localizedDescription ?? "Unknown error")"
        case .audioUnavailable:
            "Audio is not available"
        case .unsupportedAudioFormat:
            "Audio format is not supported"
        case .audioBufferOverflow:
            "Audio buffer overflow"
        case .audioSessionInterrupted:
            "Audio session interrupted"
        case .aiServiceUnavailable:
            "AI service is temporarily unavailable"
        case .modelLoadFailed:
            "Failed to load AI model"
        case .inferenceError:
            "AI processing error occurred"
        case .insufficientData:
            "Not enough data for AI analysis"
        case .modelNotReady:
            "AI model is not ready yet"
        case .maxRetriesExceeded:
            "Operation failed after maximum retry attempts"
        case let .aiGenerationFailed(error):
            "AI generation failed: \(error.localizedDescription)"
        case let .aiAnalysisFailed(error):
            "AI analysis failed: \(error.localizedDescription)"
        case let .songFetchFailed(error):
            "Failed to fetch song: \(error.localizedDescription)"
        case let .modelDownloadFailed(error):
            "Failed to download AI model: \(error.localizedDescription)"
        case let .aiPredictionFailed(error):
            "AI prediction failed: \(error.localizedDescription)"
        case .invalidPrediction:
            "Invalid AI prediction result"
        case let .decodingFailed(error):
            "Failed to decode data: \(error.localizedDescription)"
        case let .saveFailure(error):
            "Failed to save data: \(error.localizedDescription)"
        case let .fetchFailure(error):
            "Failed to fetch data: \(error.localizedDescription)"
        case let .deletionFailure(error):
            "Failed to delete data: \(error.localizedDescription)"
        case let .mergeConflict(error):
            "Merge conflict: \(error.localizedDescription)"
        case .lowMemory:
            "Low memory"
        case .diskSpaceLow:
            "Disk space is low"
        case .networkUnavailable:
            "Network connection unavailable"
        case let .serverError(code):
            "Server error with code: \(code)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .audioLoadFailed:
            "Try selecting a different audio file"
        case .missingPermissions:
            "Open Settings to grant necessary permissions"
        case .modelNotReady:
            "Please wait for the AI model to finish loading"
        case .audioProcessingFailed:
            "Try playing a different song or restart the app"
        case .audioUnavailable:
            "Check if another app is using audio"
        case .networkUnavailable:
            "Check your internet connection"
        case .aiServiceUnavailable:
            "Try again later or restart the app"
        case .insufficientData:
            "Add more songs or continue listening"
        case .modelLoadFailed:
            "Update the app to the latest version"
        case .inferenceError:
            "Try restarting the app"
        case .maxRetriesExceeded:
            "Please try the operation again"
        default:
            "Please try again or contact support if the issue persists"
        }
    }

    var errorIcon: String {
        switch self {
        case .missingPermissions: "lock.shield"
        case .audioLoadFailed, .audioProcessingFailed, .audioUnavailable: "speaker.slash"
        case .aiServiceUnavailable, .modelLoadFailed, .inferenceError: "brain.head.profile"
        case .networkUnavailable, .serverError: "wifi.slash"
        case .saveFailure, .fetchFailure, .deletionFailure: "externaldrive.badge.exclamationmark"
        default: "exclamationmark.triangle"
        }
    }

    var shouldRetry: Bool {
        switch self {
        case .networkUnavailable, .serverError, .aiServiceUnavailable:
            true
        case .modelLoadFailed, .inferenceError:
            true
        case .audioLoadFailed, .audioProcessingFailed:
            true
        default:
            false
        }
    }

    var retryDelay: TimeInterval {
        switch self {
        case .networkUnavailable, .serverError:
            MLConfig.ErrorRecovery.retryDelay * 2
        case .modelLoadFailed, .inferenceError:
            MLConfig.ErrorRecovery.retryDelay
        default:
            MLConfig.ErrorRecovery.retryDelay
        }
    }
}

/// Error handling coordinator for the app
class ErrorCoordinator: ObservableObject {
    static let shared = ErrorCoordinator()

    // MARK: - Properties

    @Published private(set) var currentError: AppError?
    @Published private(set) var isShowingError = false
    @Published private(set) var recoveryInProgress = false

    private let logger = Logger(subsystem: "com.aimixtapes", category: "ErrorHandling")
    private var recoveryAttempts: [String: Int] = [:]
    private var errorSubscriptions = Set<AnyCancellable>()

    private init() {
        setupErrorHandling()
    }

    // MARK: - Public Methods

    func handle(_ error: AppError, in view: String) {
        logger.error("[\(view)] Error occurred: \(error.localizedDescription)")

        // Check if recovery is possible
        if let recovery = recoverFromError(error) {
            recoveryInProgress = true
            recovery
                .sink(
                    receiveCompletion: { [weak self] completion in
                        self?.recoveryInProgress = false
                        if case let .failure(error) = completion {
                            self?.showError(error)
                        }
                    },
                    receiveValue: { [weak self] _ in
                        self?.recoveryInProgress = false
                    }
                )
                .store(in: &errorSubscriptions)
        } else {
            showError(error)
        }
    }

    private func showError(_ error: AppError) {
        currentError = error
        isShowingError = true
    }

    private func recoverFromError(_ error: AppError) -> AnyPublisher<Void, Error>? {
        switch error {
        case .modelNotReady:
            retryModelLoad()
        case .networkUnavailable:
            waitForNetworkConnectivity()
        case .lowMemory:
            freeUpMemory()
        default:
            nil
        }
    }

    private func retryModelLoad() -> AnyPublisher<Void, Error> {
        // Implementation for model reload
        Future { _ in
            // Retry logic
        }.eraseToAnyPublisher()
    }

    private func waitForNetworkConnectivity() -> AnyPublisher<Void, Error> {
        // Network connectivity check implementation
        Future { _ in
            // Network check logic
        }.eraseToAnyPublisher()
    }

    private func freeUpMemory() -> AnyPublisher<Void, Error> {
        // Memory cleanup implementation
        Future { _ in
            // Memory cleanup logic
        }.eraseToAnyPublisher()
    }

    private func setupErrorHandling() {
        // Subscribe to service error publishers
        NotificationCenter.default.publisher(for: .audioServiceError)
            .compactMap { $0.object as? Error }
            .sink { [weak self] error in
                if let appError = error as? AppError {
                    self?.handle(appError, in: "AudioService")
                } else {
                    self?.handle(.audioProcessingFailed(error), in: "AudioService")
                }
            }
            .store(in: &errorSubscriptions)

        NotificationCenter.default.publisher(for: .aiServiceError)
            .compactMap { $0.object as? Error }
            .sink { [weak self] error in
                if let appError = error as? AppError {
                    self?.handle(appError, in: "AIService")
                } else {
                    self?.handle(.inferenceError, in: "AIService")
                }
            }
            .store(in: &errorSubscriptions)
    }
}

// MARK: - Error Notification Names

extension Notification.Name {
    static let audioServiceError = Notification.Name("audioServiceError")
    static let aiServiceError = Notification.Name("aiServiceError")
    static let appErrorOccurred = Notification.Name("com.aimixtapes.errorOccurred")
    static let errorRecoveryStarted = Notification.Name("com.aimixtapes.errorRecoveryStarted")
    static let errorRecoveryCompleted = Notification.Name("com.aimixtapes.errorRecoveryCompleted")
}

// MARK: - SwiftUI Error Views

struct ErrorAlert: ViewModifier {
    @ObservedObject var coordinator: ErrorCoordinator

    func body(content: Content) -> some View {
        content
            .alert(isPresented: $coordinator.isShowingError) {
                Alert(
                    title: Text("Error"),
                    message: Text(coordinator.currentError?.localizedDescription ?? "Unknown error"),
                    primaryButton: .default(Text("Retry"), action: handleRetry),
                    secondaryButton: .cancel()
                )
            }
    }

    private func handleRetry() {
        // Retry logic
    }
}

struct ErrorBanner: View {
    let error: AppError
    let action: () -> Void

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text(error.localizedDescription)
                    .font(.subheadline)
                Spacer()
                Button("Retry", action: action)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
    }
}

extension View {
    func handleErrors(with coordinator: ErrorCoordinator) -> ModifiedContent<Self, ErrorAlert> {
        modifier(ErrorAlert(coordinator: coordinator))
    }
}
