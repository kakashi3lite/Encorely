import Foundation
import CoreData
import os.log

/// Manages the Core Data stack including migrations
class PersistenceController {
    /// Shared singleton instance
    static let shared = PersistenceController()
    
    /// Logger for persistence operations
    private let logger = Logger(subsystem: "com.mixtapes.ai", category: "Persistence")
    
    /// The container holding the Core Data stack
    let container: NSPersistentContainer
    
    /// Error state tracking
    @Published var persistenceError: Error?
    
    // MARK: - Initialization
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "AI_Mixtapes")
        
        // Configure store description
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        // Configure migration options
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        
        // Enable history tracking for undo functionality
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Load persistent stores
        loadPersistentStores()
    }
    
    // MARK: - Store Loading
    
    /// Loads the persistent stores with migration handling
    private func loadPersistentStores() {
        // First try with automatic migration
        container.loadPersistentStores { [weak self] description, error in
            if let error = error {
                self?.logger.error("Failed to load persistent store with automatic migration: \(error.localizedDescription)")
                self?.handleMigrationFailure(description: description, error: error)
            } else {
                self?.logger.info("Successfully loaded persistent store with automatic migration")
                self?.configureContainer()
            }
        }
    }
    
    /// Handles migration failures by attempting manual migration
    private func handleMigrationFailure(description: NSPersistentStoreDescription, error: Error) {
        guard let storeURL = description.url else {
            self.persistenceError = error
            return
        }
        
        // Try manual migration
        logger.info("Attempting manual migration")
        let migrationManager = CoreDataMigrationManager(storeURL: storeURL)
        
        if migrationManager.migrateStore() {
            // If manual migration succeeded, try loading again
            logger.info("Manual migration successful, reloading stores")
            container.loadPersistentStores { [weak self] _, error in
                if let error = error {
                    self?.logger.error("Failed to load store after manual migration: \(error.localizedDescription)")
                    self?.persistenceError = error
                } else {
                    self?.logger.info("Successfully loaded store after manual migration")
                    self?.configureContainer()
                }
            }
        } else {
            logger.error("Manual migration failed")
            self.persistenceError = error
        }
    }
    
    /// Configures the container after successful store loading
    private func configureContainer() {
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Set up fetch request optimization
        container.viewContext.name = "viewContext"
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        // Enable batch operations on iOS 14+
        if #available(iOS 14.0, macOS 11.0, *) {
            container.viewContext.tranactionAuthor = "app"
            container.viewContext.automaticallyMergesChangesFromParent = true
        }
        
        setupNotificationHandling()
    }
    
    // MARK: - Notification Handling
    
    /// Sets up notification observers for context changes
    private func setupNotificationHandling() {
        // Listen for store remote change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
    }
    
    @objc private func storeRemoteChange(_ notification: Notification) {
        logger.debug("Received persistent store remote change notification")
        container.viewContext.perform {
            self.container.viewContext.refreshAllObjects()
        }
    }
    
    // MARK: - Background Operations
    
    /// Creates a background context for performing operations off the main thread
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// Performs a background task with a new context
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
    
    /// Performs a background task and returns a result via completion handler
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T, completion: @escaping (Result<T, Error>) -> Void) {
        container.performBackgroundTask { context in
            do {
                let result = try block(context)
                completion(.success(result))
            } catch {
                self.logger.error("Background task error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Saves all contexts that have changes
    func saveAllContexts() {
        if container.viewContext.hasChanges {
            saveContext(container.viewContext)
        }
    }
    
    /// Saves a specific context if it has changes
    func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                logger.error("Error saving context: \(error.localizedDescription)")
                persistenceError = error
                #if DEBUG
                fatalError("Error saving context: \(error)")
                #endif
            }
        }
    }
}
