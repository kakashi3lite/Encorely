import Foundation
import Combine

class MBTIProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var extraversion: Float = 0.5 {
        didSet { updatePreferences() }
    }
    
    @Published var sensing: Float = 0.5 {
        didSet { updatePreferences() }
    }
    
    @Published var thinking: Float = 0.5 {
        didSet { updatePreferences() }
    }
    
    @Published var judging: Float = 0.5 {
        didSet { updatePreferences() }
    }
    
    @Published private(set) var predictedPreferences: AudioPreferences
    
    // MARK: - Computed Properties
    
    var mbtiType: String {
        let profile = MBTIProfile(
            extraversion: extraversion,
            sensing: sensing,
            thinking: thinking,
            judging: judging
        )
        return profile.typeString
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Initialize with neutral preferences
        self.predictedPreferences = AudioPreferences(
            energy: 0.5,
            valence: 0.5,
            tempo: 120,
            complexity: 0.5,
            structure: 0.5,
            variety: 0.5
        )
        
        // Load existing profile if available
        loadSavedProfile()
    }
    
    // MARK: - Public Methods
    
    func saveProfile() {
        let profile = MBTIProfile(
            extraversion: extraversion,
            sensing: sensing,
            thinking: thinking,
            judging: judging
        )
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "mbti_profile")
        }
        
        // Notify recommendation engine
        NotificationCenter.default.post(
            name: .mbtiProfileDidChange,
            object: profile
        )
    }
    
    // MARK: - Private Methods
    
    private func loadSavedProfile() {
        guard let data = UserDefaults.standard.data(forKey: "mbti_profile"),
              let profile = try? JSONDecoder().decode(MBTIProfile.self, from: data)
        else {
            return
        }
        
        // Update UI
        self.extraversion = profile.extraversion
        self.sensing = profile.sensing
        self.thinking = profile.thinking
        self.judging = profile.judging
        
        // Update preferences
        updatePreferences()
    }
    
    private func updatePreferences() {
        let profile = MBTIProfile(
            extraversion: extraversion,
            sensing: sensing,
            thinking: thinking,
            judging: judging
        )
        
        self.predictedPreferences = profile.audioPreferences
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let mbtiProfileDidChange = Notification.Name("mbtiProfileDidChange")
}
