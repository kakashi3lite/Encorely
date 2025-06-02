import UIKit
import CoreData
import Intents

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    // MARK: - Properties
    
    var aiService: AIIntegrationService!
    var player: AVQueuePlayer!
    var siriService: SiriIntegrationService!
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AI_Mixtapes")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, 
                                  options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize services
        player = AVQueuePlayer()
        aiService = AIIntegrationService(context: persistentContainer.viewContext)
        
        // Setup audio session for background processing
        setupAudioSession()
        siriService = SiriIntegrationService(aiService: aiService, player: player, context: persistentContainer.viewContext)
        
        // Request Siri authorization
        INPreferences.requestSiriAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.aiService.siriIntegrationEnabled = status == .authorized
                if status == .authorized {
                    self?.siriService.donateShortcuts()
                }
            }
        }
        
        // Request MusicKit authorization
        Task {
            let musicService = MusicKitService.shared
            if await musicService.requestAuthorization() {
                // Access granted, request library access
                try? await musicService.requestLibraryAccess()
            }
        }
        
        // Register default UserDefaults
        registerDefaults()
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Save current state when going to background
        saveApplicationState()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Additional cleanup if needed
        saveContext()
    }
    
    // MARK: - Intents Extension Support
    
    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        // Let SiriIntegrationService handle all intents
        return siriService
    }
    
    // MARK: - State Management
    
    private func registerDefaults() {
        let defaults: [String: Any] = [
            "hasCompletedOnboarding": false,
            "preferredColorScheme": "system",
            "audioAnalysisEnabled": true,
            "useFacialExpressions": false,
            "useSiriIntegration": true
        ]
        UserDefaults.standard.register(defaults: defaults)
    }
    
    private func saveApplicationState() {
        let state = ["lastActiveTab": UserDefaults.standard.integer(forKey: "lastActiveTab"),
                    "lastActiveMood": UserDefaults.standard.string(forKey: "lastActiveMood") ?? "neutral",
                    "lastActivePersonality": UserDefaults.standard.string(forKey: "lastActivePersonality") ?? "explorer"]
        UserDefaults.standard.set(state, forKey: "applicationState")
    }
    
    // MARK: - Core Data Saving
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}