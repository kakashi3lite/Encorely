import Foundation

#if os(iOS)
    import AVFAudio
#endif

/// Manages audio session configuration across platforms
/// Provides a safe API for configuring audio sessions on iOS
/// while gracefully handling non-iOS platforms
public final class AudioSessionManager: @unchecked Sendable {
    /// Creates a new AudioSessionManager instance
    public init() {}

    /// Configure and activate the audio session if available on this platform.
    /// Safe no-op on platforms without `AVAudioSession`.
    public func configureAndActivate(category: SessionCategory = .playback) throws {
        #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            switch category {
            case .playback:
                try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            case .playAndRecord:
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            case .record:
                try session.setCategory(.record, mode: .default, options: [])
            }
            try session.setActive(true, options: [])
        #else
            _ = category // no-op on non-iOS
        #endif
    }
}

/// Audio session categories supported by AudioSessionManager
public enum SessionCategory {
    /// Playback-only mode, optimized for audio playback
    case playback
    /// Simultaneous audio playback and recording
    case playAndRecord
    /// Recording-only mode, optimized for audio input
    case record
}
