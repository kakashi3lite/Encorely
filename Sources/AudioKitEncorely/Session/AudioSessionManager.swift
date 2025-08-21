import Foundation

#if os(iOS)
import AVFAudio
import Combine
#endif

@MainActor
public final class AudioSessionManager: ObservableObject {
    
    #if os(iOS)
    private let session = AVAudioSession.sharedInstance()
    private var cancellables = Set<AnyCancellable>()
    
    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var currentRoute: String = ""
    @Published public private(set) var isInterrupted: Bool = false
    #endif
    
    public init() {
        #if os(iOS)
        setupNotifications()
        #endif
    }
    
    deinit {
        #if os(iOS)
        cancellables.removeAll()
        #endif
    }

    /// Configure and activate the audio session if available on this platform.
    /// Safe no-op on platforms without `AVAudioSession`.
    public func configureAndActivate(category: SessionCategory = .playback) throws {
        #if os(iOS)
        switch category {
        case .playback:
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .mixWithOthers])
        case .playAndRecord:
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        case .record:
            try session.setCategory(.record, mode: .default, options: [.allowBluetooth])
        }
        
        try session.setActive(true, options: [])
        isActive = true
        updateCurrentRoute()
        #else
        _ = category // no-op on non-iOS
        #endif
    }
    
    public func deactivate() throws {
        #if os(iOS)
        try session.setActive(false, options: .notifyOthersOnDeactivation)
        isActive = false
        #endif
    }
    
    #if os(iOS)
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleInterruption(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                self?.handleRouteChange(notification)
            }
            .store(in: &cancellables)
    }
    
    
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let interruptionTypeRaw = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeRaw) else {
            return
        }
        
        switch interruptionType {
        case .began:
            isInterrupted = true
            isActive = false
        case .ended:
            isInterrupted = false
            
            if let optionsRaw = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
                if options.contains(.shouldResume) {
                    do {
                        try session.setActive(true, options: [])
                        isActive = true
                    } catch {
                        print("Failed to reactivate audio session after interruption: \(error)")
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func handleRouteChange(_ notification: Notification) {
        updateCurrentRoute()
        
        guard let userInfo = notification.userInfo,
              let reasonRaw = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Handle headphone disconnect, etc.
            break
        case .newDeviceAvailable:
            // Handle new device connection
            break
        default:
            break
        }
    }
    
    private func updateCurrentRoute() {
        let outputs = session.currentRoute.outputs
        if let output = outputs.first {
            currentRoute = "\(output.portType.rawValue): \(output.portName)"
        } else {
            currentRoute = "No output"
        }
    }
    #endif
}

public enum SessionCategory {
    case playback
    case playAndRecord
    case record
}
