import AVFoundation
import Foundation
import os.log

/// Centralizes AVAudioSession configuration and interruption handling.
final class AudioSessionManager: Sendable {
    static let shared = AudioSessionManager()

    private let logger = Logger(subsystem: "com.encorely", category: "AudioSession")

    private init() {
        setupNotifications()
    }

    /// Activates the audio session for playback.
    func activate() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try session.setActive(true)
            logger.info("Audio session activated")
        } catch {
            logger.error("Audio session activation failed: \(error.localizedDescription)")
        }
    }

    /// Deactivates the audio session when not in use.
    func deactivate() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            logger.info("Audio session deactivated")
        } catch {
            logger.error("Audio session deactivation failed: \(error.localizedDescription)")
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            logger.info("Audio session interrupted")
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    activate()
                    logger.info("Audio session resumed after interruption")
                }
            }
        @unknown default:
            break
        }
    }
}
