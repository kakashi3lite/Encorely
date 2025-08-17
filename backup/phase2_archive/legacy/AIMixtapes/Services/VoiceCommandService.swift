import AVFoundation
import Combine
import Foundation
import Speech

/// Service for handling voice commands and speech recognition
class VoiceCommandService: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var isListening = false
    @Published private(set) var interimTranscript = ""
    @Published private(set) var recognitionError: Error?

    // MARK: - Private Properties

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var cancellables = Set<AnyCancellable>()
    private let commandProcessor = VoiceCommandProcessor()

    // MARK: - Initialization

    init() {
        setupNotifications()
    }

    // MARK: - Public Methods

    /// Request speech recognition authorization
    func requestAuthorization() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard status == .authorized else {
            throw VoiceCommandError.notAuthorized
        }
    }

    /// Start listening for voice commands
    func startListening() {
        guard !isListening,
              let recognizer = speechRecognizer,
              recognizer.isAvailable
        else {
            handleError(.recognizerUnavailable)
            return
        }

        do {
            try setupAudioSession()
            try startRecognition()
            isListening = true
        } catch {
            handleError(error)
        }
    }

    /// Stop listening for voice commands
    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    // MARK: - Private Methods

    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startRecognition() throws {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw VoiceCommandError.requestCreationFailed
        }

        // Configure request
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true

        // Start audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let error {
                handleError(error)
                return
            }

            guard let result else { return }

            // Handle interim results
            interimTranscript = result.bestTranscription.formattedString

            // Process final result
            if result.isFinal {
                processFinalTranscript(result.bestTranscription)
            }
        }
    }

    private func processFinalTranscript(_ transcription: SFTranscription) {
        // Extract segments for more detailed command processing
        let segments = transcription.segments.map { segment in
            VoiceSegment(
                text: segment.substring,
                confidence: segment.confidence,
                timestamp: segment.timestamp,
                duration: segment.duration
            )
        }

        // Process command segments
        commandProcessor.processCommand(
            transcript: transcription.formattedString,
            segments: segments
        )
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] _ in
                self?.stopListening()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] _ in
                self?.handleRouteChange()
            }
            .store(in: &cancellables)
    }

    private func handleRouteChange() {
        // Restart recognition if needed after route change
        if isListening {
            stopListening()
            startListening()
        }
    }

    private func handleError(_ error: Error) {
        stopListening()
        recognitionError = error
    }
}

// MARK: - Supporting Types

enum VoiceCommandError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case requestCreationFailed
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Speech recognition not authorized"
        case .recognizerUnavailable:
            "Speech recognizer is not available"
        case .requestCreationFailed:
            "Failed to create recognition request"
        case .processingFailed:
            "Failed to process voice command"
        }
    }
}

struct VoiceSegment {
    let text: String
    let confidence: Float
    let timestamp: TimeInterval
    let duration: TimeInterval
}
