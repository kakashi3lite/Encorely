import CoreData
import XCTest
@testable import App

class V2MigrationTests: XCTestCase {
    var testStoreURL: URL!
    var backupStoreURL: URL!
    var migrationManager: CoreDataMigrationManager!

    override func setUp() {
        super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
        testStoreURL = tempDir.appendingPathComponent("MigrationTest.sqlite")
        backupStoreURL = tempDir.appendingPathComponent("MigrationTest.backup.sqlite")
        migrationManager = CoreDataMigrationManager(storeURL: testStoreURL)
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: testStoreURL)
        try? FileManager.default.removeItem(at: backupStoreURL)
    }

    func testMigrationWithInvalidStore() {
        // Test migration with non-existent store
        XCTAssertFalse(migrationManager.migrateStore())
    }

    func testBackupCreation() throws {
        // Create test store
        let container = NSPersistentContainer(name: "AI_Mixtapes")
        let description = NSPersistentStoreDescription(url: testStoreURL)
        container.persistentStoreDescriptions = [description]

        let expectation = XCTestExpectation(description: "Store loaded")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)

        // Trigger migration
        XCTAssertTrue(migrationManager.migrateStore())

        // Verify backup was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupStoreURL.path))
    }

    func testMigrationTimeout() {
        // TODO: Implement timeout test with mock migration manager
    }

    func testProgressMonitoring() throws {
        let container = NSPersistentContainer(name: "AI_Mixtapes")
        container.persistentStoreDescriptions.first?.url = testStoreURL

        let expectation = XCTestExpectation(description: "Store loaded")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)

        // Create some test data
        let context = container.viewContext
        let mixtape = NSEntityDescription.insertNewObject(forEntityName: "MixTape", into: context) as! MixTape
        mixtape.title = "Test Mixtape"
        mixtape.numberOfSongs = 0
        try? context.save()

        // Perform migration
        let progressObserver = ProgressObserver()
        NotificationCenter.default.addObserver(
            progressObserver,
            selector: #selector(ProgressObserver.migrationProgressChanged(_:)),
            name: Notification.Name("MigrationProgressChanged"),
            object: nil)

        XCTAssertTrue(migrationManager.migrateStore())

        // Verify progress was monitored
        XCTAssertTrue(progressObserver.progressUpdatesReceived > 0)
    }
}

class ProgressObserver: NSObject {
    var progressUpdatesReceived = 0

    @objc func migrationProgressChanged(_ notification: Notification) {
        progressUpdatesReceived += 1
    }
}
