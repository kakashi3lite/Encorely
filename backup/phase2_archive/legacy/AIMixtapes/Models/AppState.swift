import Combine
import Foundation

class AppState: ObservableObject {
    @Published var currentMixTape: MixTape?
    @Published var isPlaying: Bool = false
    @Published var isProcessing: Bool = false
    @Published var currentMood: Mood = .neutral
    @Published var errorMessage: String?

    // Performance metrics
    @Published var audioProcessingLoad: Double = 0
    @Published var memoryUsage: Double = 0
    @Published var cpuUsage: Double = 0

    // Audio session state
    @Published var isAudioSessionActive: Bool = false
    @Published var audioSessionError: Error?

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupObservers()
    }

    private func setupObservers() {
        // Monitor memory pressure
        NotificationCenter.default.publisher(for: .audioProcessingEmergencyCleanup)
            .sink { [weak self] _ in
                self?.handleMemoryPressure()
            }
            .store(in: &cancellables)

        // Monitor performance metrics
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updatePerformanceMetrics()
            }
            .store(in: &cancellables)
    }

    private func handleMemoryPressure() {
        // Clear any cached resources
        currentMixTape = nil
        isProcessing = false

        // Show warning to user
        errorMessage = "Memory pressure detected. Some resources have been cleared."
    }

    private func updatePerformanceMetrics() {
        let metrics = PerformanceMonitor.shared.getCurrentMetrics()
        audioProcessingLoad = metrics.audioProcessingLoad
        memoryUsage = metrics.memoryUsage
        cpuUsage = metrics.cpuUsage
    }
}
