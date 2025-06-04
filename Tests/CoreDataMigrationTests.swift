import XCTest
import CoreData
@testable import App

class CoreDataMigrationTests: XCTestCase {
    var testStoreURL: URL!
    var backupStoreURL: URL!
    
    override func setUp() {
        super.setUp()
        // Create test store URL in temp directory
        let tempDir = FileManager.default.temporaryDirectory
        testStoreURL = tempDir.appendingPathComponent("TestStore.sqlite")
        backupStoreURL = tempDir.appendingPathComponent("TestStore.backup.sqlite")
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up test files
        try? FileManager.default.removeItem(at: testStoreURL)
        try? FileManager.default.removeItem(at: backupStoreURL)
    }
    
    // MARK: - Migration Tests
    
    func testMigrationPerformance() throws {
        // Create and populate v1 store
        let v1Store = try createV1Store()
        try populateTestData(in: v1Store)
        
        // Measure migration time
        let migrationManager = CoreDataMigrationManager(storeURL: testStoreURL)
        
        measure {
            XCTAssertTrue(migrationManager.migrateStore())
        }
        
        // Verify migration completed in < 5s
        let migrationStart = Date()
        XCTAssertTrue(migrationManager.migrateStore())
        let migrationTime = Date().timeIntervalSince(migrationStart)
        XCTAssertLessThan(migrationTime, 5.0, "Migration took too long: \(migrationTime) seconds")
    }
    
    func testMigrationPreservesData() throws {
        // Create and populate v1 store with test data
        let v1Store = try createV1Store()
        let testData = try populateTestData(in: v1Store)
        
        // Perform migration
        let migrationManager = CoreDataMigrationManager(storeURL: testStoreURL)
        XCTAssertTrue(migrationManager.migrateStore())
        
        // Load v2 store and verify data
        let v2Store = try loadV2Store()
        try verifyMigratedData(original: testData, migrated: v2Store)
    }
    
    func testMigrationRollback() throws {
        // Create and populate original store
        let v1Store = try createV1Store()
        let testData = try populateTestData(in: v1Store)
        
        // Force migration failure and verify rollback
        let failingManager = MockFailingMigrationManager(storeURL: testStoreURL)
        XCTAssertFalse(failingManager.migrateStore())
        
        // Load original store and verify data is intact
        let restoredStore = try loadV1Store()
        try verifyOriginalData(testData: testData, store: restoredStore)
    }
    
    // MARK: - Helper Methods
    
    private func createV1Store() throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "AI_Mixtapes")
        
        // Configure for v1 model
        let description = NSPersistentStoreDescription(url: testStoreURL)
        description.shouldMigrateStoreAutomatically = false
        container.persistentStoreDescriptions = [description]
        
        let expectation = XCTestExpectation(description: "Store loaded")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
        
        return container
    }
    
    private func populateTestData(in container: NSPersistentContainer) throws -> [TestMixtape] {
        let context = container.viewContext
        
        var testData: [TestMixtape] = []
        
        // Create test mixtapes with various properties
        for i in 0..<5 {
            let mixtape = MixTape(context: context)
            mixtape.title = "Test Mixtape \(i)"
            mixtape.numberOfSongs = Int16(i + 1)
            mixtape.createdDate = Date()
            mixtape.moodTags = "happy,energetic"
            
            let testMixtape = TestMixtape(
                title: mixtape.title,
                numberOfSongs: mixtape.numberOfSongs,
                createdDate: mixtape.createdDate
            )
            testData.append(testMixtape)
            
            // Add test songs
            for j in 0..<mixtape.numberOfSongs {
                let song = Song(context: context)
                song.name = "Test Song \(j)"
                song.positionInTape = j
                mixtape.addToSongs(song)
            }
        }
        
        try context.save()
        return testData
    }
    
    private func loadV2Store() throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "AI_Mixtapes")
        
        let expectation = XCTestExpectation(description: "Store loaded")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
        
        return container
    }
    
    private func verifyMigratedData(original: [TestMixtape], migrated: NSPersistentContainer) throws {
        let context = migrated.viewContext
        let request = NSFetchRequest<MixTape>(entityName: "MixTape")
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        let migratedMixtapes = try context.fetch(request)
        XCTAssertEqual(migratedMixtapes.count, original.count)
        
        for (originalData, migratedMixtape) in zip(original, migratedMixtapes) {
            XCTAssertEqual(migratedMixtape.title, originalData.title)
            XCTAssertEqual(migratedMixtape.numberOfSongs, originalData.numberOfSongs)
            XCTAssertEqual(migratedMixtape.createdDate, originalData.createdDate)
            XCTAssertEqual(migratedMixtape.songs.count, Int(originalData.numberOfSongs))
        }
    }
    
    private func verifyOriginalData(testData: [TestMixtape], store: NSPersistentContainer) throws {
        let context = store.viewContext
        let request = NSFetchRequest<MixTape>(entityName: "MixTape")
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        let mixtapes = try context.fetch(request)
        XCTAssertEqual(mixtapes.count, testData.count)
        
        for (original, restored) in zip(testData, mixtapes) {
            XCTAssertEqual(restored.title, original.title)
            XCTAssertEqual(restored.numberOfSongs, original.numberOfSongs)
            XCTAssertEqual(restored.createdDate, original.createdDate)
            XCTAssertEqual(restored.songs.count, Int(original.numberOfSongs))
        }
    }
    
    private func loadV1Store() throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "AI_Mixtapes")
        let description = NSPersistentStoreDescription(url: testStoreURL)
        description.shouldMigrateStoreAutomatically = false
        container.persistentStoreDescriptions = [description]
        
        let expectation = XCTestExpectation(description: "Store loaded")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
        
        return container
    }
}

// MARK: - Test Support Types

struct TestMixtape {
    let title: String
    let numberOfSongs: Int16
    let createdDate: Date
}

class MockFailingMigrationManager: CoreDataMigrationManager {
    override func migrateStore() -> Bool {
        // Simulate migration failure
        return false
    }
}
