import AVFoundation
import Foundation
import os.log

/// A thread-safe cache for managing audio buffers with advanced memory monitoring
final class AudioBufferCache {
    // MARK: - Types

    private struct CacheEntry {
        let buffer: ManagedAudioBuffer
        let lastAccess: Date
        let cost: Int
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.aimixtapes", category: "AudioBufferCache")
    private let queue = DispatchQueue(label: "com.aimixtapes.buffer.cache", attributes: .concurrent)
    private let memoryMonitor = MemoryMonitor.shared

    private var entries: [String: CacheEntry] = [:]
    private var totalCost: Int = 0
    private let maxCost: Int

    // MARK: - Initialization

    init(maxCostMB: Int = 50) {
        maxCost = maxCostMB * 1024 * 1024
        setupMemoryPressureHandling()
    }

    // MARK: - Public Methods

    func cache(_ buffer: ManagedAudioBuffer, forKey key: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }

            let cost = buffer.memorySize
            let entry = CacheEntry(buffer: buffer, lastAccess: Date(), cost: cost)

            // Remove old entry if exists
            if let oldEntry = entries[key] {
                totalCost -= oldEntry.cost
            }

            // Add new entry
            entries[key] = entry
            totalCost += cost

            // Trim if needed
            if totalCost > maxCost {
                trim(toSize: maxCost * 3 / 4)
            }
        }
    }

    func retrieveBuffer(forKey key: String) -> ManagedAudioBuffer? {
        var result: ManagedAudioBuffer?

        queue.sync {
            if let entry = entries[key] {
                result = entry.buffer
                let updatedEntry = CacheEntry(buffer: entry.buffer, lastAccess: Date(), cost: entry.cost)
                entries[key] = updatedEntry
            }
        }

        return result
    }

    func trim(toSize targetSize: Int) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }

            // Sort entries by last access time
            let sortedEntries = entries.sorted { $0.value.lastAccess < $1.value.lastAccess }

            // Remove entries until we're under target size
            for (key, entry) in sortedEntries {
                if totalCost <= targetSize {
                    break
                }

                entries.removeValue(forKey: key)
                totalCost -= entry.cost
            }
        }
    }

    func removeAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.entries.removeAll()
            self?.totalCost = 0
        }
    }

    // MARK: - Memory Pressure Handling

    private func setupMemoryPressureHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        // Monitor memory pressure periodically
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.handleMemoryPressure()
        }
    }

    private func handleMemoryPressure() {
        let pressure = memoryMonitor.currentPressureLevel

        switch pressure {
        case .critical:
            trim(toSize: maxCost / 4)
        case .high:
            trim(toSize: maxCost / 2)
        case .moderate:
            trim(toSize: maxCost * 3 / 4)
        default:
            break
        }
    }

    @objc private func handleMemoryWarning() {
        removeAll()
    }
}
