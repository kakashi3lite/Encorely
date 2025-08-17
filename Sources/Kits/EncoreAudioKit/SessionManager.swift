// filepath: Sources/Kits/EncoreAudioKit/SessionManager.swift
import AVFoundation
import Combine
import Foundation

public final class SessionManager: ObservableObject {
    public enum Event {
        case routeChanged
        case interruptionBegan
        case interruptionEnded(shouldResume: Bool)
        case configurationChanged
    }

    public static let shared = SessionManager()

    private let session = AVAudioSession.sharedInstance()
    private let queue = DispatchQueue(label: "encore.audio.session")
    private let eventSubject = PassthroughSubject<Event, Never>()
    public var events: AnyPublisher<Event, Never> { eventSubject.eraseToAnyPublisher() }

    private init() {
        configureNotifications()
    }

    @discardableResult
    public func configure(category: AVAudioSession.Category = .playAndRecord,
                          mode: AVAudioSession.Mode = .default,
                          options: AVAudioSession.CategoryOptions = [.allowBluetooth, .defaultToSpeaker]) -> Bool {
        do {
            try session.setCategory(category, mode: mode, options: options)
            try session.setPreferredSampleRate(48000)
            try session.setPreferredIOBufferDuration(0.0029) // ~128 frames at 44.1/48k
            try session.setActive(true, options: [])
            eventSubject.send(.configurationChanged)
            return true
        } catch {
            return false
        }
    }

    private func configureNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in self?.eventSubject.send(.routeChanged) }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo,
                  let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }
            switch type {
            case .began:
                self?.eventSubject.send(.interruptionBegan)
            case .ended:
                let shouldResume = (info[AVAudioSessionInterruptionOptionKey] as? UInt).map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) } ?? false
                self?.eventSubject.send(.interruptionEnded(shouldResume: shouldResume))
            @unknown default:
                break
            }
        }
    }
}
