import AVFoundation
import CoreData
import Intents
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    // MARK: - Properties

    var aiService: AIIntegrationService!
    var player: AVQueuePlayer!
    var siriService: SiriIntegrationService!

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AI_Mixtapes")
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Unresolved Core Data error: \(error)")
            }
        }
        // Merge policy & context configuration
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize services
        player = AVQueuePlayer()
        aiService = AIIntegrationService(context: persistentContainer.viewContext)
        siriService = SiriIntegrationService(
            aiService: aiService,
            player: player,
            context: persistentContainer.viewContext
        )

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

    func application(_: UIApplication, handlerFor _: INIntent) -> Any? {
        siriService
    }

    // MARK: - Core Data

    // Placeholder Core Data save method (implement as needed)
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do { try context.save() } catch { print("Core Data save error: \(error)") }
        }
    }
}
