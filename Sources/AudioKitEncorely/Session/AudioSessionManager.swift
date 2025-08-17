import Foundation

#if os(iOS)
    import AVFAudio
#endif

public final class AudioSessionManager: @unchecked Sendable {
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

public enum SessionCategory {
    case playback
    case playAndRecord
    case record
}
