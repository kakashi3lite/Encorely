import Foundation
import CoreMotion
import Combine

/// Manages sensor data collection and activity-based preference adjustments
class SensorDataManager {
    // MARK: - Properties
    
    private let motionManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    
    private var activityPublisher = PassthroughSubject<ActivityState, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // Activity thresholds
    private let highActivityThreshold = 120.0 // steps per minute
    private let moderateActivityThreshold = 80.0
    
    // MARK: - Initialization
    
    init() {
        setupActivityMonitoring()
    }
    
    // MARK: - Public Interface
    
    func startMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("Motion activity not available")
            return
        }
        
        motionManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity = activity else { return }
            self?.processActivity(activity)
        }
        
        startPedometerUpdates()
    }
    
    func stopMonitoring() {
        motionManager.stopActivityUpdates()
        pedometer.stopUpdates()
    }
    
    /// Adjust audio preferences based on current activity state
    func getActivityAdjustedPreferences(_ basePreferences: AudioPreferences) -> AudioPreferences {
        // Convert current activity state to preference modifiers
        let mods = getCurrentActivityModifiers()
        
        return AudioPreferences(
            energy: adjustPreference(basePreferences.energy, by: mods.energyMod),
            valence: adjustPreference(basePreferences.valence, by: mods.valenceMod),
            tempo: adjustTempo(basePreferences.tempo, by: mods.tempoMod),
            complexity: adjustPreference(basePreferences.complexity, by: mods.complexityMod),
            structure: adjustPreference(basePreferences.structure, by: mods.structureMod),
            variety: basePreferences.variety // Variety preference unchanged by activity
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupActivityMonitoring() {
        activityPublisher
            .debounce(for: .seconds(1.0), scheduler: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updatePreferences(for: state)
            }
            .store(in: &cancellables)
    }
    
    private func startPedometerUpdates() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let data = data, error == nil else { return }
            self?.processPedometerData(data)
        }
    }
    
    private func processActivity(_ activity: CMMotionActivity) {
        let state: ActivityState
        
        if activity.stationary {
            state = .stationary
        } else if activity.walking {
            state = .walking
        } else if activity.running {
            state = .running
        } else {
            state = .unknown
        }
        
        activityPublisher.send(state)
    }
    
    private func processPedometerData(_ data: CMPedometerData) {
        guard let cadence = data.currentCadence?.doubleValue else { return }
        
        let state: ActivityState
        if cadence > highActivityThreshold {
            state = .running
        } else if cadence > moderateActivityThreshold {
            state = .walking
        } else {
            state = .stationary
        }
        
        activityPublisher.send(state)
    }
    
    private func getCurrentActivityModifiers() -> ActivityModifiers {
        // Get latest activity state and return appropriate modifiers
        // Default to neutral modifiers if no activity data
        return .neutral
    }
    
    private func adjustPreference(_ value: Float, by modifier: Float) -> Float {
        return min(1.0, max(0.0, value + modifier))
    }
    
    private func adjustTempo(_ tempo: Float, by modifier: Float) -> Float {
        return min(180.0, max(60.0, tempo + modifier * 30.0))
    }
}

// MARK: - Supporting Types

enum ActivityState {
    case stationary
    case walking
    case running
    case unknown
}

struct ActivityModifiers {
    let energyMod: Float
    let valenceMod: Float
    let tempoMod: Float
    let complexityMod: Float
    let structureMod: Float
    
    static var neutral: ActivityModifiers {
        ActivityModifiers(
            energyMod: 0.0,
            valenceMod: 0.0,
            tempoMod: 0.0,
            complexityMod: 0.0,
            structureMod: 0.0
        )
    }
    
    static func forActivity(_ state: ActivityState) -> ActivityModifiers {
        switch state {
        case .running:
            return ActivityModifiers(
                energyMod: 0.3,
                valenceMod: 0.2,
                tempoMod: 0.5,
                complexityMod: -0.2,
                structureMod: 0.1
            )
        case .walking:
            return ActivityModifiers(
                energyMod: 0.1,
                valenceMod: 0.1,
                tempoMod: 0.2,
                complexityMod: 0.0,
                structureMod: 0.0
            )
        case .stationary:
            return ActivityModifiers(
                energyMod: -0.1,
                valenceMod: 0.0,
                tempoMod: -0.1,
                complexityMod: 0.1,
                structureMod: 0.0
            )
        case .unknown:
            return .neutral
        }
    }
}
