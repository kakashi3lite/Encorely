import Foundation
import UIKit
import CoreData
import AVFoundation

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
    
    // AI-related errors
    case aiServiceUnavailable
    case modelLoadFailed
    case inferenceError
    case insufficientData
    
    // CoreData errors
    case saveFailure(Error)
    case loadFailure(Error)
    case deletionFailure(Error)
    case entityNotFound(String)
    
    // File/Resource errors
    case fileNotFound(String)
    case invalidURL(String)
    case resourceUnavailable(String)
    
    // Network errors
    case networkUnavailable
    case requestFailed(Error)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        // App errors
        case .invalidConfiguration:
            return "App configuration is invalid"
        case .missingPermissions(let permission):
            return "Missing required permission: \(permission)"
        case .userCancelled:
            return "Action cancelled by user"
            
        // Audio errors
        case .audioLoadFailed(let error):
            return "Failed to load audio: \(error?.localizedDescription ?? "Unknown error")"
        case .audioProcessingFailed(let error):
            return "Audio processing failed: \(error?.localizedDescription ?? "Unknown error")"
        case .audioUnavailable:
            return "Audio is not available"
        case .unsupportedAudioFormat:
            return "Audio format is not supported"
            
        // AI errors
        case .aiServiceUnavailable:
            return "AI service is temporarily unavailable"
        case .modelLoadFailed:
            return "Failed to load AI model"
        case .inferenceError:
            return "AI processing error occurred"
        case .insufficientData:
            return "Not enough data for AI analysis"
            
        // CoreData errors
        case .saveFailure(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .loadFailure(let error):
            return "Failed to load data: \(error.localizedDescription)"
        case .deletionFailure(let error):
            return "Failed to delete data: \(error.localizedDescription)"
        case .entityNotFound(let entity):
            return "\(entity) not found"
            
        // File/Resource errors
        case .fileNotFound(let filename):
            return "File not found: \(filename)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .resourceUnavailable(let resource):
            return "Resource unavailable: \(resource)"
            
        // Network errors
        case .networkUnavailable:
            return "Network connection unavailable"
        case .requestFailed(let error):
            return "Network request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .missingPermissions:
            return "Please grant the required permissions in Settings"
        case .audioLoadFailed, .audioProcessingFailed:
            return "Try playing a different song or restart the app"
        case .audioUnavailable:
            return "Check if another app is using audio"
        case .networkUnavailable:
            return "Check your internet connection"
        case .aiServiceUnavailable:
            return "Try again later or restart the app"
        case .insufficientData:
            return "Add more songs or continue listening"
        default:
            return "Try again or contact support if the problem persists"
        }
    }
    
    var errorIcon: String {
        switch self {
        case .missingPermissions: return "lock.shield"
        case .audioLoadFailed, .audioProcessingFailed, .audioUnavailable: return "speaker.slash"
        case .aiServiceUnavailable, .modelLoadFailed, .inferenceError: return "brain.head.profile"
        case .networkUnavailable, .requestFailed, .invalidResponse: return "wifi.slash"
        case .saveFailure, .loadFailure, .deletionFailure: return "externaldrive.badge.exclamationmark"
        default: return "exclamationmark.triangle"
        }
    }
}

/// Error handling coordinator for the app
class ErrorCoordinator: ObservableObject {
    static let shared = ErrorCoordinator()
    
    @Published var currentError: AppError?
    @Published var showingError = false
    
    private var errorPublishers = Set<AnyCancellable>()
    
    private init() {
        setupErrorHandling()
    }
    
    func handle(_ error: AppError) {
        DispatchQueue.main.async {
            self.currentError = error
            self.showingError = true
        }
    }
    
    private func setupErrorHandling() {
        // Subscribe to error publishers from services
        NotificationCenter.default.publisher(for: .audioServiceError)
            .compactMap { $0.object as? Error }
            .sink { [weak self] error in
                if let appError = error as? AppError {
                    self?.handle(appError)
                } else {
                    self?.handle(.audioProcessingFailed(error))
                }
            }
            .store(in: &errorPublishers)
        
        NotificationCenter.default.publisher(for: .aiServiceError)
            .compactMap { $0.object as? Error }
            .sink { [weak self] error in
                if let appError = error as? AppError {
                    self?.handle(appError)
                } else {
                    self?.handle(.inferenceError)
                }
            }
            .store(in: &errorPublishers)
    }
}

// MARK: - Error Notification Names
extension Notification.Name {
    static let audioServiceError = Notification.Name("audioServiceError")
    static let aiServiceError = Notification.Name("aiServiceError")
}

// MARK: - SwiftUI Error Views
struct ErrorAlert: ViewModifier {
    @ObservedObject var coordinator = ErrorCoordinator.shared
    
    func body(content: Content) -> some View {
        content
            .alert(isPresented: $coordinator.showingError) {
                Alert(
                    title: Text("Error"),
                    message: Text(coordinator.currentError?.localizedDescription ?? "An unknown error occurred")
                        + Text("\n\n")
                        + Text(coordinator.currentError?.recoverySuggestion ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
}

struct ErrorBanner: View {
    let error: AppError
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: error.errorIcon)
                    .foregroundColor(.red)
                Text(error.localizedDescription)
                    .font(.subheadline)
                Spacer()
                Button(action: action) {
                    Text("Retry")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 2)
            
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
}

extension View {
    func withErrorHandling() -> some View {
        self.modifier(ErrorAlert())
    }
}
