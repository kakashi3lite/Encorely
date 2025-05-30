import Foundation
import CoreMotion
import Combine

/// Service for collecting and analyzing sensor data to enhance music recommendations
public class SensorDataManager: ObservableObject {
    // Published properties for UI updates
    @Published private(set) var currentActivity: ActivityType = .stationary
    @Published private(set) var activityConfidence: Double = 0.0
    @Published private(set) var motionIntensity: Float = 0.0
    
    // Core Motion manager
    private let motionManager = CMMotionActivityManager()
    private let motionQueue = OperationQueue()
    private var activityTimer: Timer?
    
    // Store recent sensor readings
    private var recentMotionReadings: [Float] = []
    private let maxReadings = 100
    
    public init() {
        setupMotionTracking()
    }
    
    /// Start monitoring user activity
    public func startMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("Motion activity not available")
            return
        }
        
        motionManager.startActivityUpdates(to: motionQueue) { [weak self] activity in
            guard let activity = activity else { return }
            
            DispatchQueue.main.async {
                self?.processActivity(activity)
            }
        }
        
        // Start periodic intensity updates
        activityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMotionIntensity()
        }
    }
    
    /// Stop monitoring user activity
    public func stopMonitoring() {
        motionManager.stopActivityUpdates()
        activityTimer?.invalidate()
        activityTimer = nil
    }
    
    /// Get activity-adjusted audio preferences
    public func getActivityAdjustedPreferences(_ basePreferences: AudioPreferences) -> AudioPreferences {
        // Adjust preferences based on current activity and motion intensity
        let energyAdjustment = motionIntensity * 0.3  // Up to 30% energy boost based on motion
        let tempoAdjustment = motionIntensity * 20    // Up to 20 BPM increase based on motion
        
        return AudioPreferences(
            energy: min(1.0, basePreferences.energy + energyAdjustment),
            valence: basePreferences.valence,
            tempo: min(180.0, basePreferences.tempo + tempoAdjustment),
            complexity: basePreferences.complexity * (1.0 - motionIntensity * 0.3), // Reduce complexity during high activity
            structure: basePreferences.structure,
            variety: basePreferences.variety + motionIntensity * 0.2 // Increase variety during high activity
        )
    }
    
    // MARK: - Private Methods
    
    private func setupMotionTracking() {
        motionQueue.qualityOfService = .userInteractive
    }
    
    private func processActivity(_ activity: CMMotionActivity) {
        // Update current activity type
        if activity.stationary {
            currentActivity = .stationary
        } else if activity.walking {
            currentActivity = .walking
        } else if activity.running {
            currentActivity = .running
        } else if activity.cycling {
            currentActivity = .cycling
        } else if activity.automotive {
            currentActivity = .automotive
        }
        
        // Update confidence
        activityConfidence = activity.confidence.rawValue / 2.0
    }
    
    private func updateMotionIntensity() {
        // Add new motion intensity reading based on current activity
        let newIntensity: Float
        switch currentActivity {
        case .stationary:
            newIntensity = 0.0
        case .walking:
            newIntensity = 0.3
        case .running:
            newIntensity = 0.8
        case .cycling:
            newIntensity = 0.6
        case .automotive:
            newIntensity = 0.1
        }
        
        // Add reading and maintain history size
        recentMotionReadings.append(newIntensity)
        if recentMotionReadings.count > maxReadings {
            recentMotionReadings.removeFirst()
        }
        
        // Calculate smoothed intensity
        motionIntensity = recentMotionReadings.reduce(0, +) / Float(recentMotionReadings.count)
    }
}

/// Types of physical activity that can be detected
public enum ActivityType: String, Codable {
    case stationary = "Stationary"
    case walking = "Walking"
    case running = "Running"
    case cycling = "Cycling"
    case automotive = "In Vehicle"
    
    var description: String {
        rawValue
    }
}
