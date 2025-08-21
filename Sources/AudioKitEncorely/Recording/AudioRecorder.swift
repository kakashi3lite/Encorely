import Foundation
import AVFoundation
import Combine

// MARK: - Audio Recording Session
@MainActor
public class AudioRecorder: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isRecording = false
    @Published public private(set) var recordingLevel: Float = 0.0
    @Published public private(set) var recordingDuration: TimeInterval = 0.0
    @Published public private(set) var currentSession: RecordingSession?
    @Published public private(set) var error: AudioRecorderError?
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var durationTimer: Timer?
    private let audioSessionManager = AudioSessionManager()
    
    // MARK: - Recording Configuration
    public struct RecordingConfiguration {
        let format: AudioFormat
        let sampleRate: Double
        let channels: Int
        let quality: AVAudioQuality
        
        public static let professional = RecordingConfiguration(
            format: .wav,
            sampleRate: 44100,
            channels: 2,
            quality: .max
        )
        
        public static let standard = RecordingConfiguration(
            format: .m4a,
            sampleRate: 44100,
            channels: 1,
            quality: .high
        )
    }
    
    public enum AudioFormat: String, CaseIterable {
        case wav = "wav"
        case m4a = "m4a"
        case aiff = "aiff"
        case caf = "caf"
        
        var fileExtension: String { rawValue }
        
        var settings: [String: Any] {
            switch self {
            case .wav:
                return [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM),
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsFloatKey: false
                ]
            case .m4a:
                return [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
            case .aiff:
                return [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM),
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsBigEndianKey: true,
                    AVLinearPCMIsFloatKey: false
                ]
            case .caf:
                return [
                    AVFormatIDKey: Int(kAudioFormatAppleLossless)
                ]
            }
        }
    }
    
    // MARK: - Initialization
    public override init() {
        super.init()
    }
    
    // MARK: - Recording Control
    public func startRecording(
        configuration: RecordingConfiguration = .professional,
        filename: String? = nil
    ) async throws {
        guard !isRecording else {
            throw AudioRecorderError.alreadyRecording
        }
        
        do {
            try await setupAudioSession()
            try await createRecorder(configuration: configuration, filename: filename)
            
            guard let recorder = audioRecorder else {
                throw AudioRecorderError.recorderInitializationFailed
            }
            
            // Enable level metering
            recorder.isMeteringEnabled = true
            
            // Start recording
            let success = recorder.record()
            guard success else {
                throw AudioRecorderError.recordingFailed
            }
            
            // Update state
            isRecording = true
            recordingDuration = 0.0
            
            // Create recording session
            currentSession = RecordingSession(
                id: UUID(),
                filename: recorder.url.lastPathComponent,
                url: recorder.url,
                configuration: configuration,
                startTime: Date()
            )
            
            // Start monitoring
            startLevelMonitoring()
            startDurationTracking()
            
        } catch {
            isRecording = false
            self.error = AudioRecorderError.from(error)
            throw error
        }
    }
    
    public func stopRecording() async -> RecordingSession? {
        guard isRecording, let recorder = audioRecorder else {
            return nil
        }
        
        // Stop recording
        recorder.stop()
        isRecording = false
        recordingLevel = 0.0
        
        // Stop monitoring
        stopLevelMonitoring()
        stopDurationTracking()
        
        // Finalize session
        if let session = currentSession {
            let finalSession = RecordingSession(
                id: session.id,
                filename: session.filename,
                url: session.url,
                configuration: session.configuration,
                startTime: session.startTime,
                endTime: Date(),
                duration: recordingDuration,
                fileSize: getFileSize(url: session.url)
            )
            
            currentSession = finalSession
            
            // Save to session manager
            await SessionManager.shared.saveSession(finalSession)
            
            return finalSession
        }
        
        return nil
    }
    
    public func pauseRecording() throws {
        guard isRecording, let recorder = audioRecorder else {
            throw AudioRecorderError.notRecording
        }
        
        recorder.pause()
        stopLevelMonitoring()
        stopDurationTracking()
    }
    
    public func resumeRecording() throws {
        guard let recorder = audioRecorder else {
            throw AudioRecorderError.notRecording
        }
        
        let success = recorder.record()
        guard success else {
            throw AudioRecorderError.recordingFailed
        }
        
        startLevelMonitoring()
        startDurationTracking()
    }
    
    // MARK: - Private Methods
    private func setupAudioSession() async throws {
        try audioSessionManager.configureAndActivate(category: .record)
    }
    
    private func createRecorder(
        configuration: RecordingConfiguration,
        filename: String?
    ) async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                   in: .userDomainMask)[0]
        
        let fileName = filename ?? generateFilename(format: configuration.format)
        let recordingURL = documentsPath.appendingPathComponent(fileName)
        
        var settings = configuration.format.settings
        settings[AVSampleRateKey] = configuration.sampleRate
        settings[AVNumberOfChannelsKey] = configuration.channels
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
        } catch {
            throw AudioRecorderError.recorderInitializationFailed
        }
    }
    
    private func generateFilename(format: AudioFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "Recording_\(timestamp).\(format.fileExtension)"
    }
    
    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRecordingLevel()
            }
        }
    }
    
    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    private func startDurationTracking() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRecordingDuration()
            }
        }
    }
    
    private func stopDurationTracking() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    private func updateRecordingLevel() {
        guard let recorder = audioRecorder else { return }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let normalizedLevel = pow(10.0, averagePower / 20.0)
        recordingLevel = Float(normalizedLevel)
    }
    
    private func updateRecordingDuration() {
        guard let recorder = audioRecorder else { return }
        recordingDuration = recorder.currentTime
    }
    
    private func getFileSize(url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                self.error = AudioRecorderError.recordingFailed
            }
        }
    }
    
    nonisolated public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.error = AudioRecorderError.from(error)
        }
    }
}

// MARK: - Recording Session
public struct RecordingSession: Identifiable, Equatable {
    public let id: UUID
    public let filename: String
    public let url: URL
    public let configuration: AudioRecorder.RecordingConfiguration
    public let startTime: Date
    public let endTime: Date?
    public let duration: TimeInterval?
    public let fileSize: Int64?
    
    public init(
        id: UUID,
        filename: String,
        url: URL,
        configuration: AudioRecorder.RecordingConfiguration,
        startTime: Date,
        endTime: Date? = nil,
        duration: TimeInterval? = nil,
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.filename = filename
        self.url = url
        self.configuration = configuration
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.fileSize = fileSize
    }
    
    public var isComplete: Bool {
        endTime != nil
    }
    
    public var formattedDuration: String {
        guard let duration = duration else { return "00:00" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public var formattedFileSize: String {
        guard let fileSize = fileSize else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    public static func == (lhs: RecordingSession, rhs: RecordingSession) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Recording Configuration Extensions
extension AudioRecorder.RecordingConfiguration: Equatable {}

extension AudioRecorder.RecordingConfiguration: Codable {
    enum CodingKeys: String, CodingKey {
        case format, sampleRate, channels, quality
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = try container.decode(AudioRecorder.AudioFormat.self, forKey: .format)
        sampleRate = try container.decode(Double.self, forKey: .sampleRate)
        channels = try container.decode(Int.self, forKey: .channels)
        let qualityRawValue = try container.decode(Int.self, forKey: .quality)
        quality = AVAudioQuality(rawValue: qualityRawValue) ?? .medium
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(format, forKey: .format)
        try container.encode(sampleRate, forKey: .sampleRate)
        try container.encode(channels, forKey: .channels)
        try container.encode(quality.rawValue, forKey: .quality)
    }
}

extension AudioRecorder.AudioFormat: Codable {}

extension RecordingSession: Codable {
    enum CodingKeys: String, CodingKey {
        case id, filename, url, configuration, startTime, endTime, duration, fileSize
    }
}

// MARK: - Audio Recorder Error
public enum AudioRecorderError: LocalizedError {
    case alreadyRecording
    case notRecording
    case recorderInitializationFailed
    case recordingFailed
    case audioSessionError(Error)
    case fileSystemError(Error)
    case unknown(Error?)
    
    public var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No active recording session"
        case .recorderInitializationFailed:
            return "Failed to initialize audio recorder"
        case .recordingFailed:
            return "Recording operation failed"
        case .audioSessionError(let error):
            return "Audio session error: \(error.localizedDescription)"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown error: \(error?.localizedDescription ?? "No details")"
        }
    }
    
    static func from(_ error: Error?) -> AudioRecorderError {
        guard let error = error else { return .unknown(nil) }
        
        if error is AudioRecorderError {
            return error as! AudioRecorderError
        }
        
        return .unknown(error)
    }
}

// MARK: - Session Manager
@MainActor
public class SessionManager: ObservableObject {
    public static let shared = SessionManager()
    
    @Published public private(set) var sessions: [RecordingSession] = []
    
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "saved_recording_sessions"
    
    private init() {
        loadSessions()
    }
    
    public func saveSession(_ session: RecordingSession) async {
        sessions.append(session)
        await persistSessions()
    }
    
    public func deleteSession(_ session: RecordingSession) async {
        // Remove from array
        sessions.removeAll { $0.id == session.id }
        
        // Delete file
        do {
            try FileManager.default.removeItem(at: session.url)
        } catch {
            print("Failed to delete recording file: \(error)")
        }
        
        await persistSessions()
    }
    
    public func getSessions() -> [RecordingSession] {
        return sessions.sorted { $0.startTime > $1.startTime }
    }
    
    private func loadSessions() {
        guard let data = userDefaults.data(forKey: sessionsKey),
              let decodedSessions = try? JSONDecoder().decode([RecordingSession].self, from: data) else {
            return
        }
        
        // Verify files still exist
        sessions = decodedSessions.filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }
    
    private func persistSessions() async {
        do {
            let data = try JSONEncoder().encode(sessions)
            userDefaults.set(data, forKey: sessionsKey)
        } catch {
            print("Failed to persist sessions: \(error)")
        }
    }
}