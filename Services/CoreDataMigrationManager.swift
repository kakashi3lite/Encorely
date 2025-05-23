import Foundation
import CoreData
import os.log

/// Manages CoreData migrations between versions
class CoreDataMigrationManager: NSObject {
    /// Maximum time allowed for migration in seconds
    private let migrationTimeout: TimeInterval = 5.0
    
    /// Error types specific to migration
    enum MigrationError: Error {
        case timeout
        case migrationFailed(String)
    }
    private let logger = Logger(subsystem: "com.mixtapes.ai", category: "CoreDataMigration")
    
    /// The URL for the persistent store
    private let storeURL: URL
    
    /// Available model versions in order of creation (oldest first)
    private let modelVersions = ["AI_Mixtapes", "AI_Mixtapes_v2"]
    
    init(storeURL: URL) {
        self.storeURL = storeURL
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(NSMigrationManager.migrationProgress),
           let progress = change?[.newKey] as? Float {
            logger.info("Migration progress: \(Int(progress * 100))%")
        }
    }
    
    /// Performs required migrations to bring the persistent store up to the current model version
    /// - Returns: Bool indicating if migration was successful
    func migrateStore() -> Bool {
        guard needsMigration() else {
            logger.info("No migration needed, store is at current version")
            return true
        }
        
        logger.info("Beginning CoreData migration process")
        
        do {
            // Determine source and destination model versions
            guard let sourceVersion = try determineSourceVersion(),
                  let destinationVersion = modelVersions.last else {
                logger.error("Failed to determine source or destination model versions")
                return false
            }
            
            logger.info("Migrating from \(sourceVersion) to \(destinationVersion)")
            
            if sourceVersion == modelVersions.first && destinationVersion == modelVersions.last {
                // Perform direct migration from first to latest version
                return try migrateFromV1ToV2()
            } else {
                // For more complex situations, implement incremental migration path
                return try performIncrementalMigration(from: sourceVersion)
            }
            
        } catch {
            logger.error("Migration failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Checks if the store needs migration
    /// - Returns: Boolean indicating if migration is needed
    private func needsMigration() -> Bool {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            // No store exists yet, so no migration needed
            return false
        }
        
        do {
            // Get metadata from persistent store
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )
            
            // Get current model and check compatibility
            guard let currentModel = NSManagedObjectModel.mergedModel(
                from: [Bundle.main]
            ) else {
                logger.error("Failed to create current model")
                return true // Assume migration needed if we can't determine
            }
            
            return !currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
            
        } catch {
            logger.error("Error checking migration status: \(error.localizedDescription)")
            return true // Assume migration needed on error
        }
    }
    
    /// Determines the version of the existing store
    /// - Returns: String representing the model version
    private func determineSourceVersion() throws -> String? {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        
        // Check compatibility with each model version
        for version in modelVersions {
            if let model = managedObjectModel(forVersion: version),
               model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
                return version
            }
        }
        
        return nil
    }
    
    /// Gets the managed object model for a specific version
    /// - Parameter version: The model version
    /// - Returns: The managed object model
    private func managedObjectModel(forVersion version: String) -> NSManagedObjectModel? {
        guard let modelURL = Bundle.main.url(
            forResource: version,
            withExtension: "momd"
        ) else {
            return nil
        }
        
        return NSManagedObjectModel(contentsOf: modelURL)
    }
    
    /// Performs migration from v1 to v2 schema
    private func migrateFromV1ToV2() throws -> Bool {
        guard let sourceModel = managedObjectModel(forVersion: "AI_Mixtapes"),
              let destinationModel = managedObjectModel(forVersion: "AI_Mixtapes_v2") else {
            logger.error("Failed to load source or destination models")
            return false
        }
        
        // Create mapping model
        guard let mappingModel = NSMappingModel(from: [Bundle.main], 
                                               forSourceModel: sourceModel, 
                                               destinationModel: destinationModel) else {
            logger.error("Failed to create mapping model - may need custom mapping model")
            return false
        }
        
        // Create migration manager
        let manager = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        
        // Add progress tracking
        var migrationProgress: Float = 0
        manager.addObserver(self, forKeyPath: #keyPath(NSMigrationManager.migrationProgress), options: [.new], context: nil)
        
        // Temporary destination URL
        let destinationURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent("AI_Mixtapes_v2.sqlite")
        
        // Perform migration
        try manager.migrateStore(
            from: storeURL,
            sourceType: NSSQLiteStoreType,
            options: nil,
            with: mappingModel,
            toDestinationURL: destinationURL,
            destinationType: NSSQLiteStoreType,
            destinationOptions: nil
        )
        
        // Replace old store with new one
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: destinationModel)
        try coordinator.replacePersistentStore(
            at: storeURL,
            destinationOptions: nil,
            withPersistentStoreFrom: destinationURL,
            sourceOptions: nil,
            ofType: NSSQLiteStoreType
        )
        
        // Clean up temporary store
        try FileManager.default.removeItem(at: destinationURL)
        
        logger.info("Successfully migrated from v1 to v2")
        return true
    }
    
    /// Performs incremental migration through multiple versions
    private func performIncrementalMigration(from sourceVersion: String) throws -> Bool {
        guard let sourceVersionIndex = modelVersions.firstIndex(of: sourceVersion),
              sourceVersionIndex < modelVersions.count - 1 else {
            return true // Already at latest version
        }
        
        // Start with the source version
        var currentVersion = sourceVersion
        
        // Iterate through each version step
        for versionIndex in sourceVersionIndex..<(modelVersions.count - 1) {
            let nextVersion = modelVersions[versionIndex + 1]
            
            logger.info("Incrementally migrating from \(currentVersion) to \(nextVersion)")
            
            // Perform individual step migration
            if !try migrateStoreStep(from: currentVersion, to: nextVersion) {
                return false
            }
            
            // Update current version
            currentVersion = nextVersion
        }
        
        return true
    }
    
    /// Migrates between two consecutive versions
    private func migrateStoreStep(from sourceVersion: String, to destinationVersion: String) throws -> Bool {
        // Implement step migration between consecutive versions
        // This would typically call specific migration methods like migrateFromV1ToV2()
        
        if sourceVersion == "AI_Mixtapes" && destinationVersion == "AI_Mixtapes_v2" {
            return try migrateFromV1ToV2()
        }
        
        // Add more version transitions as needed
        
        logger.error("No migration path defined from \(sourceVersion) to \(destinationVersion)")
        return false
    }
}
