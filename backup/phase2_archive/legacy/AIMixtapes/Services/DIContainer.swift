import AVFoundation
import CoreData
import Foundation

class DIContainer {
    // MARK: - Shared Instance

    static let shared = DIContainer()

    // MARK: - Core Services

    let persistenceController = PersistenceController.shared
    lazy var audioProcessor = AudioProcessor()
    lazy var audioConfiguration = AudioProcessingConfiguration.shared

    // Access to managed context
    var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    // MARK: - Service Configuration

    private init() {
        setupDependencies()
    }

    private func setupDependencies() {
        // Setup audio session for the whole app
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker]
            )
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }

        // Add any additional setup here
    }

    // MARK: - Helper Methods

    func resetCoreData() {
        // Helper method for development/testing
        let coordinator = persistenceController.container.persistentStoreCoordinator
        do {
            try coordinator.persistentStores.forEach { store in
                try coordinator.remove(store)
            }
            try persistenceController.container.persistentStoreDescriptions.forEach { description in
                try coordinator.addPersistentStore(type: .sqlite, configuration: nil, at: description.url, options: nil)
            }
        } catch {
            print("Failed to reset Core Data: \(error)")
        }
    }
}
