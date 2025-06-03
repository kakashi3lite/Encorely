import Foundation
import CoreData
import CloudKit
import os.log

class PersistenceController {
    static let shared = PersistenceController()
    
    private let logger = Logger(subsystem: "com.mixtapes.ai", category: "Persistence")
    let container: NSPersistentContainer
    @Published var persistenceError: Error?
    
    private init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "AI_Mixtapes")
        
        // Configure store description
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }
        
        // Enable CloudKit
        let cloudKitOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.mixtapes.ai")
        description.cloudKitContainerOptions = cloudKitOptions
        
        // Enable history tracking and change notifications
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Load persistent stores
        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                self?.logger.error("Failed to load persistent store: \(error.localizedDescription)")
                self?.persistenceError = error
            }
            self?.configureContainer()
        }
    }
    
    private func configureContainer() {
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        if #available(iOS 14.0, macOS 11.0, *) {
            container.viewContext.transactionAuthor = "app"
            container.viewContext.name = "viewContext"
            container.viewContext.undoManager = nil
        }
        
        setupNotificationHandling()
    }
    
    private func setupNotificationHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
    }
    
    @objc private func storeRemoteChange(_ notification: Notification) {
        logger.debug("Received store remote change notification")
        container.viewContext.perform {
            self.container.viewContext.refreshAllObjects()
        }
    }
    
    // MARK: - Public Methods
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
    
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await container.performBackgroundTask(block)
    }
    
    func saveContext(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            logger.error("Context save error: \(error.localizedDescription)")
            context.rollback()
            persistenceError = error
        }
    }
}
