import AVFoundation
import Foundation
import os.log

/// Manages lifecycle and monitoring of audio buffer usage
final class AudioBufferLifecycle {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.aimixtapes", category: "AudioBufferLifecycle")
    private let queue = DispatchQueue(label: "com.aimixtapes.buffer.lifecycle", attributes: .concurrent)
    private let metrics = AudioBufferMetrics()

    private var activeBuffers: [UUID: BufferUsageInfo] = [:]
    private var retiredBuffers: [UUID: BufferUsageInfo] = [:]
    private let maxRetiredBuffers = 100

    private struct BufferUsageInfo {
        let buffer: ManagedAudioBuffer
        let creationTime: Date
        var lastUseTime: Date
        var useCount: Int
        var totalProcessingTime: TimeInterval

        var idleTime: TimeInterval {
            Date().timeIntervalSince(lastUseTime)
        }

        var lifetime: TimeInterval {
            Date().timeIntervalSince(creationTime)
        }

        var averageProcessingTime: TimeInterval {
            useCount > 0 ? totalProcessingTime / Double(useCount) : 0
        }
    }

    // MARK: - Public Methods

    func trackBuffer(_ buffer: ManagedAudioBuffer) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }

            let info = BufferUsageInfo(
                buffer: buffer,
                creationTime: Date(),
                lastUseTime: Date(),
                useCount: 1,
                totalProcessingTime: 0
            )

            activeBuffers[buffer.id] = info
            metrics.recordBufferAllocation(size: buffer.memorySize)

            logger.debug("Started tracking buffer \(buffer.id)")
        }
    }

    func recordBufferUse(_ buffer: ManagedAudioBuffer, processingTime: TimeInterval) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }

            if var info = activeBuffers[buffer.id] {
                info.lastUseTime = Date()
                info.useCount += 1
                info.totalProcessingTime += processingTime
                activeBuffers[buffer.id] = info
            }
        }
    }

    func retireBuffer(_ buffer: ManagedAudioBuffer) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }

            if let info = activeBuffers.removeValue(forKey: buffer.id) {
                // Record metrics
                metrics.recordBufferRelease(
                    size: buffer.memorySize,
                    lifetime: info.lifetime
                )

                // Keep info for analysis
                retiredBuffers[buffer.id] = info

                // Trim retired buffers if needed
                if retiredBuffers.count > maxRetiredBuffers {
                    retiredBuffers.removeValue(forKey: retiredBuffers.keys.first!)
                }

                logger.debug("Retired buffer \(buffer.id)")
            }
        }
    }

    func analyzeBufferUsage() -> String {
        queue.sync {
            let activeCount = activeBuffers.count
            let retiredCount = retiredBuffers.count

            let totalUseCount = activeBuffers.values.reduce(0) { $0 + $1.useCount }
            let avgProcessingTime = activeBuffers.values.map(\.averageProcessingTime).reduce(0, +) / Double(max(
                activeBuffers.count,
                1
            ))

            return """
            Buffer Usage Analysis
            -------------------
            Active Buffers: \(activeCount)
            Retired Buffers: \(retiredCount)
            Total Uses: \(totalUseCount)
            Average Processing Time: \(String(format: "%.3f", avgProcessingTime))s

            Metrics:
            \(metrics.generateReport())
            """
        }
    }

    func cleanupIdleBuffers(olderThan age: TimeInterval) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }

            let now = Date()
            let idleBuffers = activeBuffers.filter {
                now.timeIntervalSince($0.value.lastUseTime) > age
            }

            for (id, info) in idleBuffers {
                activeBuffers.removeValue(forKey: id)
                retiredBuffers[id] = info
                metrics.recordBufferRelease(
                    size: info.buffer.memorySize,
                    lifetime: info.lifetime
                )
            }

            if !idleBuffers.isEmpty {
                logger.info("Cleaned up \(idleBuffers.count) idle buffers")
            }
        }
    }

    func reset() {
        queue.async(flags: .barrier) { [weak self] in
            self?.activeBuffers.removeAll()
            self?.retiredBuffers.removeAll()
            self?.metrics.reset()
        }
    }
}
