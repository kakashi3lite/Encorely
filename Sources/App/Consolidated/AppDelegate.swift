import CoreData
import Intents
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@main
#if canImport(UIKit)
class AppDelegate: UIResponder, UIApplicationDelegate {
#elseif canImport(AppKit)
class AppDelegate: NSObject, NSApplicationDelegate {
#endif
    // MARK: - Properties

    var aiService: AIIntegrationService!
    var player: AVQueuePlayer!
    var siriService: SiriIntegrationService!

    lazy var persistentContainer: NSPersistentContainer = {
        // ...existing container code...
    }()

#if canImport(UIKit)
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
        // Let SiriIntegrationService handle all intents
        siriService
    }
#elseif canImport(AppKit)
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize services for macOS
        player = AVQueuePlayer()
        aiService = AIIntegrationService(context: persistentContainer.viewContext)
        siriService = SiriIntegrationService(
            aiService: aiService,
            player: player,
            context: persistentContainer.viewContext
        )
    }
#endif

    // MARK: - Core Data

    // ...existing Core Data methods...
}
