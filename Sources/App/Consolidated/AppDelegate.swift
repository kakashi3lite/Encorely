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
        // ...existing container code...
    }()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize services
        player = AVQueuePlayer()
        aiService = AIIntegrationService(context: persistentContainer.viewContext)
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
        
        return true
    }
    
    // MARK: - Intents Extension Support
    
    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        // Let SiriIntegrationService handle all intents
        return siriService
    }
    
    // MARK: - Core Data
    
    // ...existing Core Data methods...
}