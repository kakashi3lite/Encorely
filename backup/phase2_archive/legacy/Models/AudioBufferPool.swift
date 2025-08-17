import AVFoundation
import Foundation
import os.log

/// Manages a pool of reusable audio buffers with memory pressure handling
final class AudioBufferPool {
    // MARK: - Properties

    private let maxPoolSize: Int = 50 * 1024 * 1024 // 50 MB limit
    private let logger = Logger(subsystem: "com.aimixtapes", category: "AudioBufferPool")

    private var inUseBuffers: Set<ManagedAudioBuffer> = []
    private var availableBuffers: Set<ManagedAudioBuffer> = []
    private var currentPoolSize: Int = 0
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var reuseCount: Int = 0
    private var totalAllocations: Int = 0

    // MARK: - Initialization

    init() {
        setupMemoryPressureHandling()
        registerForMemoryWarnings()

        logger.info("AudioBufferPool initialized with \(maxPoolSize) bytes limit")
    }

    // MARK: - Public Methods

    /// Request a buffer with specified format and frame capacity
    func requestBuffer(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        let requiredSize = calculateBufferSize(format: format, frameCapacity: frameCapacity)

        // Try to reuse an available buffer
        if let reusableBuffer = findReusableBuffer(format: format, frameCapacity: frameCapacity) {
            reuseCount += 1
            moveBufferToInUse(reusableBuffer)
            logger.debug("Reusing buffer. Reuse efficiency: \(calculateReuseEfficiency())%")
            return reusableBuffer.buffer
        }

        // Check if we can allocate a new buffer
        guard currentPoolSize + requiredSize <= maxPoolSize else {
            logger.error("Cannot allocate buffer - pool size limit reached")
            cleanupOnMemoryWarning() // Try emergency cleanup
            return nil
        }

        // Create new buffer
        guard let newBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            logger.error("Failed to create new audio buffer")
            return nil
        }

        let managedBuffer = ManagedAudioBuffer(buffer: newBuffer, size: requiredSize)
        moveBufferToInUse(managedBuffer)
        currentPoolSize += requiredSize
        totalAllocations += 1

        logger.debug("Created new buffer. Pool size: \(currentPoolSize)/\(maxPoolSize) bytes")
        return newBuffer
    }

    /// Return a buffer to the pool
    func returnBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let managedBuffer = inUseBuffers.first(where: { $0.buffer === buffer }) else {
            logger.error("Attempted to return unmanaged buffer")
            return
        }

        inUseBuffers.remove(managedBuffer)
        availableBuffers.insert(managedBuffer)
        logger.debug("Buffer returned to pool. Available buffers: \(availableBuffers.count)")
    }

    // MARK: - Memory Pressure Handling

    private func setupMemoryPressureHandling() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical])
        memoryPressureSource?.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        memoryPressureSource?.resume()
    }

    private func registerForMemoryWarnings() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cleanupOnMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil)
    }

    @objc private func cleanupOnMemoryWarning() {
        logger.warning("Memory warning received - performing cleanup")

        // Immediately free unused buffers
        let freedSize = availableBuffers.reduce(0) { $0 + $1.size }
        availableBuffers.removeAll()
        currentPoolSize -= freedSize

        logger.info("Freed \(freedSize) bytes from pool")
    }

    private func handleMemoryPressure() {
        guard let pressure = memoryPressureSource?.data else { return }

        switch pressure {
            case .warning:
                logger.warning("Memory pressure warning - releasing non-essential buffers")
                releaseNonEssentialBuffers()

            case .critical:
                logger.error("Critical memory pressure - performing emergency cleanup")
                cleanupOnMemoryWarning()
                AIIntegrationService.shared.unloadUnusedModels()

            default:
                break
        }
    }

    // MARK: - Helper Methods

    private func releaseNonEssentialBuffers() {
        // Keep only recently used buffers
        let oldBuffers = availableBuffers.filter {
            Date().timeIntervalSince($0.lastUsed) > 30 // 30 seconds threshold
        }

        let freedSize = oldBuffers.reduce(0) { $0 + $1.size }
        availableBuffers.subtract(oldBuffers)
        currentPoolSize -= freedSize

        logger.info("Released \(oldBuffers.count) non-essential buffers, freed \(freedSize) bytes")
    }

    private func findReusableBuffer(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> ManagedAudioBuffer? {
        availableBuffers.first { buffer in
            buffer.buffer.format == format && buffer.buffer.frameCapacity >= frameCapacity
        }
    }

    private func moveBufferToInUse(_ buffer: ManagedAudioBuffer) {
        availableBuffers.remove(buffer)
        inUseBuffers.insert(buffer)
        buffer.lastUsed = Date()
    }

    private func calculateBufferSize(format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> Int {
        let bytesPerFrame = format.streamDescription.pointee.mBytesPerFrame
        return Int(bytesPerFrame * frameCapacity)
    }

    private func calculateReuseEfficiency() -> Double {
        guard totalAllocations > 0 else { return 0 }
        return Double(reuseCount) / Double(totalAllocations) * 100
    }
}
