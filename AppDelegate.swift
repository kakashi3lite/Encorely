import UIKit
import CoreData
import os.log

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }

    // MARK: - Core Data stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AI_Mixtapes")
        
        // Configure CloudKit integration
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.mixtapes.ai")
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        // Handle migrations before loading stores
        if let storeURL = description.url {
            let migrationManager = CoreDataMigrationManager(storeURL: storeURL)
            
            // Perform migration with timeout
            let semaphore = DispatchSemaphore(value: 0)
            var migrationError: Error?
            
            DispatchQueue.global(qos: .userInitiated).async {
                if !migrationManager.migrateStore() {
                    migrationError = CoreDataMigrationManager.MigrationError.migrationFailed("Migration failed")
                }
                semaphore.signal()
            }
            
            if semaphore.wait(timeout: .now() + 5.0) == .timedOut {
                migrationError = CoreDataMigrationManager.MigrationError.timeout
            }
            
            if let error = migrationError {
                print("WARNING: Core Data migration failed: \(error.localizedDescription)")
            }
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Rather than crashing, log the error and show an alert to the user
                print("Core Data store error: \(error), \(error.userInfo)")
                
                // Post notification for UI to display error
                NotificationCenter.default.post(
                    name: Notification.Name("CoreDataLoadError"),
                    object: error
                )
            }
        }
        
        // Configure automatic merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()

    // MARK: - Core Data Saving
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Core Data save error: \(nserror), \(nserror.userInfo)")
                
                // Post notification for UI to display error
                NotificationCenter.default.post(
                    name: Notification.Name("CoreDataSaveError"),
                    object: error
                )
            }
        }
    }
}
