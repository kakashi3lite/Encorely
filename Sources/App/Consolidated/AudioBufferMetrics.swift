import Foundation
import os.log

/// Metrics tracker for audio buffer performance and memory usage
final class AudioBufferMetrics {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.aimixtapes", category: "AudioBufferMetrics")
    private let queue = DispatchQueue(label: "com.aimixtapes.metrics")

    // Memory metrics
    private(set) var peakMemoryUsage: Int = 0
    private(set) var peakBufferCount: Int = 0
    private(set) var totalAllocations: Int = 0
    private(set) var totalReleases: Int = 0
    private(set) var reuseCount: Int = 0
    private(set) var missedRequests: Int = 0

    // Performance metrics
    private var bufferLifetimes: [TimeInterval] = []
    private var memoryHistory: [(timestamp: Date, usage: Int)] = []
    private let maxHistoryPoints = 100

    // Current state
    private(set) var currentMemoryUsage: Int = 0
    private(set) var currentBufferCount: Int = 0

    // MARK: - Public Methods

    func recordBufferAllocation(size: Int) {
        queue.async { [weak self] in
            guard let self else { return }

            totalAllocations += 1
            currentMemoryUsage += size
            currentBufferCount += 1

            peakMemoryUsage = max(peakMemoryUsage, currentMemoryUsage)
            peakBufferCount = max(peakBufferCount, currentBufferCount)

            updateMemoryHistory()
        }
    }

    func recordBufferRelease(size: Int, lifetime: TimeInterval) {
        queue.async { [weak self] in
            guard let self else { return }

            totalReleases += 1
            currentMemoryUsage -= size
            currentBufferCount -= 1

            bufferLifetimes.append(lifetime)
            if bufferLifetimes.count > maxHistoryPoints {
                bufferLifetimes.removeFirst()
            }

            updateMemoryHistory()
        }
    }

    func recordBufferReuse() {
        queue.async { [weak self] in
            self?.reuseCount += 1
        }
    }

    func recordMissedRequest() {
        queue.async { [weak self] in
            self?.missedRequests += 1
        }
    }

    // MARK: - Analytics

    var averageBufferLifetime: TimeInterval {
        queue.sync {
            guard !bufferLifetimes.isEmpty else { return 0 }
            return bufferLifetimes.reduce(0, +) / Double(bufferLifetimes.count)
        }
    }

    var reuseEfficiency: Double {
        queue.sync {
            guard totalAllocations > 0 else { return 0 }
            return Double(reuseCount) / Double(totalAllocations) * 100
        }
    }

    var memoryUtilization: Double {
        queue.sync {
            guard peakMemoryUsage > 0 else { return 0 }
            return Double(currentMemoryUsage) / Double(peakMemoryUsage) * 100
        }
    }

    func getMemoryTrend() -> MemoryTrend {
        queue.sync {
            guard memoryHistory.count >= 2 else { return .stable }

            let recentPoints = memoryHistory.suffix(10)
            let changes = zip(recentPoints.dropLast(), recentPoints.dropFirst())
                .map { $1.usage - $0.usage }

            let avgChange = Double(changes.reduce(0, +)) / Double(changes.count)
            let threshold = Double(peakMemoryUsage) / 100 // 1% change threshold

            if avgChange > threshold {
                return .increasing
            } else if avgChange < -threshold {
                return .decreasing
            }
            return .stable
        }
    }

    func generateReport() -> String {
        queue.sync {
            """
            Audio Buffer Metrics Report
            -------------------------
            Current Memory Usage: \(formatBytes(currentMemoryUsage))
            Peak Memory Usage: \(formatBytes(peakMemoryUsage))
            Current Buffer Count: \(currentBufferCount)
            Peak Buffer Count: \(peakBufferCount)
            Total Allocations: \(totalAllocations)
            Total Releases: \(totalReleases)
            Reuse Count: \(reuseCount)
            Missed Requests: \(missedRequests)
            Average Buffer Lifetime: \(String(format: "%.2f", averageBufferLifetime))s
            Reuse Efficiency: \(String(format: "%.1f", reuseEfficiency))%
            Memory Utilization: \(String(format: "%.1f", memoryUtilization))%
            Memory Trend: \(getMemoryTrend())
            """
        }
    }

    // MARK: - Private Methods

    private func updateMemoryHistory() {
        let now = Date()
        memoryHistory.append((now, currentMemoryUsage))

        if memoryHistory.count > maxHistoryPoints {
            memoryHistory.removeFirst()
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.2f MB", mb)
    }

    func reset() {
        queue.async { [weak self] in
            guard let self else { return }

            peakMemoryUsage = 0
            peakBufferCount = 0
            totalAllocations = 0
            totalReleases = 0
            reuseCount = 0
            missedRequests = 0
            currentMemoryUsage = 0
            currentBufferCount = 0
            bufferLifetimes.removeAll()
            memoryHistory.removeAll()
        }
    }
}
