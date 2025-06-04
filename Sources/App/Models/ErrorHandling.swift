import Foundation
import UIKit
import CoreData
import AVFoundation
import os.log
import Combine

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
            return "Invalid app configuration"
        case .missingPermissions(let permission):
            return "Missing permission: \(permission)"
        case .userCancelled:
            return "Operation cancelled by user"
        case .audioLoadFailed(let error):
            return "Failed to load audio: \(error?.localizedDescription ?? "Unknown error")"
        case .audioProcessingFailed(let error):
            return "Audio processing failed: \(error?.localizedDescription ?? "Unknown error")"
        case .audioUnavailable:
            return "Audio is not available"
        case .unsupportedAudioFormat:
            return "Audio format is not supported"
        case .audioBufferOverflow:
            return "Audio buffer overflow"
        case .audioSessionInterrupted:
            return "Audio session interrupted"
        case .aiServiceUnavailable:
            return "AI service is temporarily unavailable"
        case .modelLoadFailed:
            return "Failed to load AI model"
        case .inferenceError:
            return "AI processing error occurred"
        case .insufficientData:
            return "Not enough data for AI analysis"
        case .modelNotReady:
            return "AI model is not ready yet"
        case .maxRetriesExceeded:
            return "Operation failed after maximum retry attempts"
        case .aiGenerationFailed(let error):
            return "AI generation failed: \(error.localizedDescription)"
        case .aiAnalysisFailed(let error):
            return "AI analysis failed: \(error.localizedDescription)"
        case .songFetchFailed(let error):
            return "Failed to fetch song: \(error.localizedDescription)"
        case .modelDownloadFailed(let error):
            return "Failed to download AI model: \(error.localizedDescription)"
        case .aiPredictionFailed(let error):
            return "AI prediction failed: \(error.localizedDescription)"
        case .invalidPrediction:
            return "Invalid AI prediction result"
        case .decodingFailed(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        case .saveFailure(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .fetchFailure(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .deletionFailure(let error):
            return "Failed to delete data: \(error.localizedDescription)"
        case .mergeConflict(let error):
            return "Merge conflict: \(error.localizedDescription)"
        case .lowMemory:
            return "Low memory"
        case .diskSpaceLow:
            return "Disk space is low"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .serverError(let code):
            return "Server error with code: \(code)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .audioLoadFailed:
            return "Try selecting a different audio file"
        case .missingPermissions:
            return "Open Settings to grant necessary permissions"
        case .modelNotReady:
            return "Please wait for the AI model to finish loading"
        case .audioProcessingFailed:
            return "Try playing a different song or restart the app"
        case .audioUnavailable:
            return "Check if another app is using audio"
        case .networkUnavailable:
            return "Check your internet connection"
        case .aiServiceUnavailable:
            return "Try again later or restart the app"
        case .insufficientData:
            return "Add more songs or continue listening"
        case .modelLoadFailed:
            return "Update the app to the latest version"
        case .inferenceError:
            return "Try restarting the app"
        case .maxRetriesExceeded:
            return "Please try the operation again"
        default:
            return "Please try again or contact support if the issue persists"
        }
    }
    
    var errorIcon: String {
        switch self {
        case .missingPermissions: return "lock.shield"
        case .audioLoadFailed, .audioProcessingFailed, .audioUnavailable: return "speaker.slash"
        case .aiServiceUnavailable, .modelLoadFailed, .inferenceError: return "brain.head.profile"
        case .networkUnavailable, .serverError: return "wifi.slash"
        case .saveFailure, .fetchFailure, .deletionFailure: return "externaldrive.badge.exclamationmark"
        default: return "exclamationmark.triangle"
        }
    }
    
    var shouldRetry: Bool {
        switch self {
        case .networkUnavailable, .serverError, .aiServiceUnavailable:
            return true
        case .modelLoadFailed, .inferenceError:
            return true
        case .audioLoadFailed, .audioProcessingFailed:
            return true
        default:
            return false
        }
    }
    
    var retryDelay: TimeInterval {
        switch self {
        case .networkUnavailable, .serverError:
            return MLConfig.ErrorRecovery.retryDelay * 2
        case .modelLoadFailed, .inferenceError:
            return MLConfig.ErrorRecovery.retryDelay
        default:
            return MLConfig.ErrorRecovery.retryDelay
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
                        if case .failure(let error) = completion {
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
            return retryModelLoad()
        case .networkUnavailable:
            return waitForNetworkConnectivity()
        case .lowMemory:
            return freeUpMemory()
        default:
            return nil
        }
    }
    
    private func retryModelLoad() -> AnyPublisher<Void, Error> {
        // Implementation for model reload
        return Future { promise in
            // Retry logic
        }.eraseToAnyPublisher()
    }
    
    private func waitForNetworkConnectivity() -> AnyPublisher<Void, Error> {
        // Network connectivity check implementation
        return Future { promise in
            // Network check logic
        }.eraseToAnyPublisher()
    }
    
    private func freeUpMemory() -> AnyPublisher<Void, Error> {
        // Memory cleanup implementation
        return Future { promise in
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
    func handleErrors(with coordinator: ErrorCoordinator) -> some View {
        self.modifier(ErrorAlert(coordinator: coordinator))
    }
}