import AVFoundation
import Combine
import Foundation

/// Bridge class that connects our enhanced AudioAnalysisService with the existing MoodEngine
class AudioAnalysisBridge {
    // MARK: - Properties

    private let audioAnalysisService: AudioAnalysisService
    private var cancellables = Set<AnyCancellable>()
    private let notificationCenter = NotificationCenter.default

    // MARK: - Initialization

    init(audioAnalysisService: AudioAnalysisService = AudioAnalysisService()) {
        self.audioAnalysisService = audioAnalysisService

        // Set up subscriptions to forward audio features
        setupSubscriptions()
    }

    // MARK: - Setup Methods

    private func setupSubscriptions() {
        // Forward audio features to MoodEngine via notification
        audioAnalysisService.$currentFeatures
            .compactMap { $0 }
            .sink { [weak self] features in
                self?.notificationCenter.post(
                    name: .audioFeaturesUpdated,
                    object: features
                )
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Analyzes an audio file and returns the features
    /// - Parameter url: URL of the audio file to analyze
    /// - Returns: A Future containing the analysis results or an error
    func analyzeAudioFile(at url: URL) -> AnyPublisher<AudioFeatures, Error> {
        audioAnalysisService.analyzeAudio(at: url, options: .comprehensive)
    }

    /// Analyzes an audio file asynchronously
    /// - Parameter url: URL of the audio file to analyze
    /// - Returns: The audio features extracted from the file
    func analyzeAudioFile(at url: URL) async throws -> AudioFeatures {
        try await withCheckedThrowingContinuation { continuation in
            let cancellable = analyzeAudioFile(at: url)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case let .failure(error):
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { features in
                        continuation.resume(returning: features)
                    }
                )

            // Store cancellable to prevent premature deallocation
            cancellables.insert(cancellable)
        }
    }

    /// Cancels any ongoing analysis
    func cancelAnalysis() {
        audioAnalysisService.cancelCurrentAnalysis()
    }

    /// Gets the current performance metrics
    /// - Returns: Performance report as a string
    func getPerformanceMetrics() -> String {
        audioAnalysisService.getPerformanceStatistics()
    }
}

// MARK: - Extension for Notifications

extension Notification.Name {
    /// Posted when audio features are updated
    static let audioFeaturesUpdated = Notification.Name("audioFeaturesUpdated")
}
