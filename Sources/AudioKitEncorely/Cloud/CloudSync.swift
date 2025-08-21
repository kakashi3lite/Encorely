import Foundation
import CloudKit
import Combine
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Cloud Synchronization Engine
@MainActor
public class CloudSync: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isConnected = false
    @Published public private(set) var isSyncing = false
    @Published public private(set) var syncProgress: Float = 0.0
    @Published public private(set) var cloudStorage: CloudStorage?
    @Published public private(set) var syncError: CloudSyncError?
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var storageUsed: Int64 = 0
    @Published public private(set) var storageLimit: Int64 = 0
    
    // MARK: - Cloud Providers
    public enum CloudProvider: String, CaseIterable, Identifiable {
        case icloud = "icloud"
        case dropbox = "dropbox"
        case googledrive = "googledrive"
        case onedrive = "onedrive"
        case encorely = "encorely" // Our own cloud service
        
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .icloud: return "iCloud Drive"
            case .dropbox: return "Dropbox"
            case .googledrive: return "Google Drive"
            case .onedrive: return "OneDrive"
            case .encorely: return "Encorely Cloud"
            }
        }
        
        public var icon: String {
            switch self {
            case .icloud: return "icloud.fill"
            case .dropbox: return "folder.fill"
            case .googledrive: return "folder.badge.gearshape"
            case .onedrive: return "folder.circle"
            case .encorely: return "cloud.bolt.rain.fill"
            }
        }
        
        #if canImport(UIKit)
        public var color: UIColor {
            switch self {
            case .icloud: return .systemBlue
            case .dropbox: return .systemIndigo
            case .googledrive: return .systemGreen
            case .onedrive: return .systemPurple
            case .encorely: return .systemOrange
            }
        }
        #endif
        
        public var freeStorageGB: Int {
            switch self {
            case .icloud: return 5
            case .dropbox: return 2
            case .googledrive: return 15
            case .onedrive: return 5
            case .encorely: return 10 // Generous free tier
            }
        }
    }
    
    // MARK: - Cloud Storage Info
    public struct CloudStorage {
        public let provider: CloudProvider
        public let userID: String
        public let email: String
        public let isPremium: Bool
        public let storageUsed: Int64
        public let storageLimit: Int64
        public let lastSync: Date
        public let autoSyncEnabled: Bool
        
        public var storageUsedPercentage: Float {
            guard storageLimit > 0 else { return 0 }
            return Float(storageUsed) / Float(storageLimit)
        }
        
        public var availableStorage: Int64 {
            return max(0, storageLimit - storageUsed)
        }
        
        public var formattedStorageUsed: String {
            return ByteCountFormatter.string(fromByteCount: storageUsed, countStyle: .file)
        }
        
        public var formattedStorageLimit: String {
            return ByteCountFormatter.string(fromByteCount: storageLimit, countStyle: .file)
        }
    }
    
    // MARK: - Sync Configuration
    public struct SyncConfiguration {
        public let autoSync: Bool
        public let syncQuality: SyncQuality
        public let wifiOnly: Bool
        public let backgroundSync: Bool
        public let syncMetadata: Bool
        public let compressBeforeUpload: Bool
        public let conflictResolution: ConflictResolution
        
        public enum SyncQuality: String, CaseIterable {
            case original = "original"
            case compressed = "compressed"
            case optimized = "optimized"
            
            public var displayName: String {
                switch self {
                case .original: return "Original Quality"
                case .compressed: return "Compressed (Save Space)"
                case .optimized: return "Optimized (Balanced)"
                }
            }
            
            public var compressionRatio: Float {
                switch self {
                case .original: return 1.0
                case .compressed: return 0.3
                case .optimized: return 0.6
                }
            }
        }
        
        public enum ConflictResolution: String, CaseIterable {
            case askUser = "ask_user"
            case keepBoth = "keep_both"
            case keepNewest = "keep_newest"
            case keepLocal = "keep_local"
            case keepCloud = "keep_cloud"
            
            public var displayName: String {
                switch self {
                case .askUser: return "Ask Me"
                case .keepBoth: return "Keep Both Versions"
                case .keepNewest: return "Keep Newest"
                case .keepLocal: return "Keep Local Version"
                case .keepCloud: return "Keep Cloud Version"
                }
            }
        }
        
        public static let standard = SyncConfiguration(
            autoSync: true,
            syncQuality: .optimized,
            wifiOnly: true,
            backgroundSync: true,
            syncMetadata: true,
            compressBeforeUpload: false,
            conflictResolution: .askUser
        )
    }
    
    // MARK: - Cloud File
    public struct CloudFile: Identifiable, Codable {
        public let id: UUID
        public let filename: String
        public let cloudPath: String
        public let localURL: URL?
        public let cloudURL: String
        public let fileSize: Int64
        public let createdDate: Date
        public let modifiedDate: Date
        public let lastSyncDate: Date
        public let checksum: String
        public let metadata: FileMetadata
        public let syncStatus: SyncStatus
        
        public struct FileMetadata: Codable {
            public let duration: TimeInterval?
            public let format: String
            public let sampleRate: Double?
            public let channels: Int?
            public let quality: String?
            public let tags: [String]
            public let isEnhanced: Bool
            public let enhancementType: String?
        }
        
        public enum SyncStatus: String, Codable, CaseIterable {
            case synced = "synced"
            case uploading = "uploading"
            case downloading = "downloading"
            case conflict = "conflict"
            case error = "error"
            case pending = "pending"
            
            public var displayName: String {
                switch self {
                case .synced: return "Synced"
                case .uploading: return "Uploading"
                case .downloading: return "Downloading"
                case .conflict: return "Conflict"
                case .error: return "Error"
                case .pending: return "Pending"
                }
            }
            
            public var icon: String {
                switch self {
                case .synced: return "checkmark.icloud"
                case .uploading: return "icloud.and.arrow.up"
                case .downloading: return "icloud.and.arrow.down"
                case .conflict: return "exclamationmark.icloud"
                case .error: return "xmark.icloud"
                case .pending: return "clock.arrow.circlepath"
                }
            }
        }
    }
    
    // MARK: - Private Properties
    private let cloudKitContainer: CKContainer
    private let database: CKDatabase
    private var configuration: SyncConfiguration
    private var syncTimer: Timer?
    
    // MARK: - Initialization
    public init(configuration: SyncConfiguration = .standard) {
        self.configuration = configuration
        self.cloudKitContainer = CKContainer.default()
        self.database = cloudKitContainer.privateCloudDatabase
        
        Task {
            await checkCloudKitStatus()
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    // MARK: - Connection Management
    public func connectToCloud(provider: CloudProvider) async throws {
        switch provider {
        case .icloud:
            try await connectToiCloud()
        case .encorely:
            try await connectToEncorelyCloud()
        default:
            try await connectToThirdPartyProvider(provider)
        }
    }
    
    public func disconnectFromCloud() async {
        isConnected = false
        cloudStorage = nil
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - File Operations
    public func uploadFile(
        localURL: URL,
        tags: [String] = [],
        overwrite: Bool = false
    ) async throws -> CloudFile {
        
        guard isConnected else {
            throw CloudSyncError.notConnected
        }
        
        guard !isSyncing else {
            throw CloudSyncError.syncInProgress
        }
        
        isSyncing = true
        syncProgress = 0.0
        
        do {
            let fileSize = getFileSize(url: localURL)
            let checksum = try calculateChecksum(url: localURL)
            let metadata = try await extractFileMetadata(url: localURL)
            
            syncProgress = 0.2
            
            let cloudPath = generateCloudPath(for: localURL)
            let cloudURL = try await uploadToCloudStorage(
                localURL: localURL,
                cloudPath: cloudPath
            )
            
            syncProgress = 0.8
            
            let cloudFile = CloudFile(
                id: UUID(),
                filename: localURL.lastPathComponent,
                cloudPath: cloudPath,
                localURL: localURL,
                cloudURL: cloudURL,
                fileSize: fileSize,
                createdDate: Date(),
                modifiedDate: Date(),
                lastSyncDate: Date(),
                checksum: checksum,
                metadata: CloudFile.FileMetadata(
                    duration: metadata.duration,
                    format: localURL.pathExtension,
                    sampleRate: metadata.sampleRate,
                    channels: metadata.channels,
                    quality: metadata.quality,
                    tags: tags,
                    isEnhanced: false,
                    enhancementType: nil
                ),
                syncStatus: .synced
            )
            
            try await saveCloudFileRecord(cloudFile)
            
            syncProgress = 1.0
            isSyncing = false
            lastSyncDate = Date()
            
            return cloudFile
            
        } catch {
            isSyncing = false
            syncError = CloudSyncError.from(error)
            throw error
        }
    }
    
    public func downloadFile(cloudFile: CloudFile) async throws -> URL {
        guard isConnected else {
            throw CloudSyncError.notConnected
        }
        
        let localURL = generateLocalURL(for: cloudFile)
        
        // Download from cloud storage
        try await downloadFromCloudStorage(
            cloudURL: cloudFile.cloudURL,
            localURL: localURL
        )
        
        // Verify checksum
        let downloadedChecksum = try calculateChecksum(url: localURL)
        guard downloadedChecksum == cloudFile.checksum else {
            throw CloudSyncError.checksumMismatch
        }
        
        return localURL
    }
    
    public func deleteFile(cloudFile: CloudFile) async throws {
        guard isConnected else {
            throw CloudSyncError.notConnected
        }
        
        // Delete from cloud storage
        try await deleteFromCloudStorage(cloudPath: cloudFile.cloudPath)
        
        // Delete local record
        try await deleteCloudFileRecord(cloudFile)
        
        // Delete local file if exists
        if let localURL = cloudFile.localURL,
           FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
    }
    
    public func syncAllFiles() async throws {
        guard isConnected else {
            throw CloudSyncError.notConnected
        }
        
        isSyncing = true
        syncProgress = 0.0
        
        do {
            let cloudFiles = try await fetchCloudFileRecords()
            let localFiles = getLocalAudioFiles()
            
            let totalOperations = cloudFiles.count + localFiles.count
            var completedOperations = 0
            
            // Download missing files
            for cloudFile in cloudFiles {
                if cloudFile.localURL == nil ||
                   !FileManager.default.fileExists(atPath: cloudFile.localURL!.path) {
                    _ = try await downloadFile(cloudFile: cloudFile)
                }
                completedOperations += 1
                syncProgress = Float(completedOperations) / Float(totalOperations)
            }
            
            // Upload new local files
            let cloudPaths = Set(cloudFiles.map { $0.cloudPath })
            for localURL in localFiles {
                let cloudPath = generateCloudPath(for: localURL)
                if !cloudPaths.contains(cloudPath) {
                    _ = try await uploadFile(localURL: localURL)
                }
                completedOperations += 1
                syncProgress = Float(completedOperations) / Float(totalOperations)
            }
            
            isSyncing = false
            lastSyncDate = Date()
            
        } catch {
            isSyncing = false
            syncError = CloudSyncError.from(error)
            throw error
        }
    }
    
    // MARK: - Auto Sync
    public func startAutoSync() {
        guard configuration.autoSync else { return }
        
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                do {
                    try await self.syncAllFiles()
                } catch {
                    await MainActor.run {
                        self.syncError = CloudSyncError.from(error)
                    }
                }
            }
        }
    }
    
    public func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - Storage Management
    public func getStorageInfo() async throws -> CloudStorage {
        guard let storage = cloudStorage else {
            throw CloudSyncError.notConnected
        }
        
        // Update storage usage
        let currentUsage = try await calculateStorageUsage()
        
        let updatedStorage = CloudStorage(
            provider: storage.provider,
            userID: storage.userID,
            email: storage.email,
            isPremium: storage.isPremium,
            storageUsed: currentUsage,
            storageLimit: storage.storageLimit,
            lastSync: Date(),
            autoSyncEnabled: storage.autoSyncEnabled
        )
        
        self.cloudStorage = updatedStorage
        return updatedStorage
    }
    
    public func cleanupOldFiles(olderThan days: Int) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cloudFiles = try await fetchCloudFileRecords()
        
        for cloudFile in cloudFiles {
            if cloudFile.modifiedDate < cutoffDate {
                try await deleteFile(cloudFile: cloudFile)
            }
        }
    }
    
    // MARK: - Private Implementation
    private func connectToiCloud() async throws {
        let accountStatus = try await cloudKitContainer.accountStatus()
        
        guard accountStatus == .available else {
            throw CloudSyncError.icloudNotAvailable
        }
        
        // Test database access
        _ = try await database.allRecordZones()
        
        // Create user info
        let userRecord = try await cloudKitContainer.userRecordID()
        
        cloudStorage = CloudStorage(
            provider: .icloud,
            userID: userRecord.recordName,
            email: "icloud.user@apple.com", // iCloud doesn't provide email
            isPremium: false,
            storageUsed: 0,
            storageLimit: Int64(5 * 1024 * 1024 * 1024), // 5GB
            lastSync: Date(),
            autoSyncEnabled: configuration.autoSync
        )
        
        isConnected = true
    }
    
    private func connectToEncorelyCloud() async throws {
        // Implementation for our own cloud service
        // This would involve API calls to our backend
        
        cloudStorage = CloudStorage(
            provider: .encorely,
            userID: "user_123",
            email: "user@example.com",
            isPremium: false,
            storageUsed: 0,
            storageLimit: Int64(10 * 1024 * 1024 * 1024), // 10GB
            lastSync: Date(),
            autoSyncEnabled: configuration.autoSync
        )
        
        isConnected = true
    }
    
    private func connectToThirdPartyProvider(_ provider: CloudProvider) async throws {
        // Implementation for third-party providers (Dropbox, Google Drive, OneDrive)
        // This would require OAuth authentication and API integration
        
        throw CloudSyncError.providerNotSupported
    }
    
    private func checkCloudKitStatus() async {
        do {
            let status = try await cloudKitContainer.accountStatus()
            await MainActor.run {
                self.isConnected = status == .available
            }
        } catch {
            await MainActor.run {
                self.syncError = CloudSyncError.from(error)
            }
        }
    }
    
    private func uploadToCloudStorage(localURL: URL, cloudPath: String) async throws -> String {
        // Implementation for actual cloud upload
        // This is a placeholder - real implementation would depend on provider
        return "https://cloud.encorely.com/\(cloudPath)"
    }
    
    private func downloadFromCloudStorage(cloudURL: String, localURL: URL) async throws {
        // Implementation for actual cloud download
        // This is a placeholder
    }
    
    private func deleteFromCloudStorage(cloudPath: String) async throws {
        // Implementation for cloud deletion
    }
    
    private func saveCloudFileRecord(_ cloudFile: CloudFile) async throws {
        // Save to CloudKit or our database
        let record = CKRecord(recordType: "CloudFile", recordID: CKRecord.ID(recordName: cloudFile.id.uuidString))
        record["filename"] = cloudFile.filename
        record["cloudPath"] = cloudFile.cloudPath
        record["fileSize"] = cloudFile.fileSize
        record["checksum"] = cloudFile.checksum
        
        _ = try await database.save(record)
    }
    
    private func fetchCloudFileRecords() async throws -> [CloudFile] {
        let query = CKQuery(recordType: "CloudFile", predicate: NSPredicate(value: true))
        let results = try await database.records(matching: query)
        
        return results.matchResults.compactMap { result in
            try? result.1.get()
        }.compactMap { record in
            // Convert CKRecord to CloudFile
            // This is simplified - real implementation would be more robust
            return nil // Placeholder
        }
    }
    
    private func deleteCloudFileRecord(_ cloudFile: CloudFile) async throws {
        let recordID = CKRecord.ID(recordName: cloudFile.id.uuidString)
        _ = try await database.deleteRecord(withID: recordID)
    }
    
    private func extractFileMetadata(url: URL) async throws -> (duration: TimeInterval?, sampleRate: Double?, channels: Int?, quality: String?) {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            return (
                duration: Double(audioFile.length) / audioFile.fileFormat.sampleRate,
                sampleRate: audioFile.fileFormat.sampleRate,
                channels: Int(audioFile.fileFormat.channelCount),
                quality: "High"
            )
        } catch {
            return (duration: nil, sampleRate: nil, channels: nil, quality: nil)
        }
    }
    
    private func calculateChecksum(url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return data.sha256
    }
    
    private func generateCloudPath(for localURL: URL) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = localURL.lastPathComponent
        return "recordings/\(timestamp)/\(filename)"
    }
    
    private func generateLocalURL(for cloudFile: CloudFile) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(cloudFile.filename)
    }
    
    private func getLocalAudioFiles() -> [URL] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioExtensions = ["m4a", "wav", "aiff", "mp3", "caf", "flac"]
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            return files.filter { url in
                audioExtensions.contains(url.pathExtension.lowercased())
            }
        } catch {
            return []
        }
    }
    
    private func getFileSize(url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func calculateStorageUsage() async throws -> Int64 {
        let cloudFiles = try await fetchCloudFileRecords()
        return cloudFiles.reduce(0) { $0 + $1.fileSize }
    }
}

// MARK: - Error Handling
public enum CloudSyncError: LocalizedError {
    case notConnected
    case syncInProgress
    case icloudNotAvailable
    case providerNotSupported
    case insufficientStorage
    case networkError
    case checksumMismatch
    case uploadFailed
    case downloadFailed
    case authenticationRequired
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to cloud service"
        case .syncInProgress:
            return "Sync operation already in progress"
        case .icloudNotAvailable:
            return "iCloud is not available"
        case .providerNotSupported:
            return "Cloud provider not supported"
        case .insufficientStorage:
            return "Insufficient cloud storage space"
        case .networkError:
            return "Network connection error"
        case .checksumMismatch:
            return "File verification failed"
        case .uploadFailed:
            return "Failed to upload file"
        case .downloadFailed:
            return "Failed to download file"
        case .authenticationRequired:
            return "Cloud authentication required"
        case .unknown(let error):
            return "Cloud sync error: \(error.localizedDescription)"
        }
    }
    
    static func from(_ error: Error) -> CloudSyncError {
        if let cloudError = error as? CloudSyncError {
            return cloudError
        }
        return .unknown(error)
    }
}

// MARK: - Data Extensions
extension Data {
    var sha256: String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

import CryptoKit