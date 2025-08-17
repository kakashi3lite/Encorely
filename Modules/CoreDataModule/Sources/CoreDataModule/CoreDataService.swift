import CoreData
import Foundation

public protocol CoreDataServiceProtocol {
    func saveContext() throws
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) throws -> [T]
    func delete(_ object: NSManagedObject) throws
}

public class CoreDataService: CoreDataServiceProtocol {
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    public init(modelName: String) {
        container = NSPersistentContainer(name: modelName)
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data store failed to load: \(error.localizedDescription)")
            }
        }
        context = container.viewContext
    }

    public func saveContext() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    public func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) throws -> [T] {
        try context.fetch(request)
    }

    public func delete(_ object: NSManagedObject) throws {
        context.delete(object)
        try saveContext()
    }
}
