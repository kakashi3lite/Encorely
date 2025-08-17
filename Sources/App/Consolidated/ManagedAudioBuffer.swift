import AVFoundation
import Foundation

/// Enhanced wrapper for AVAudioPCMBuffer with comprehensive memory tracking
final class ManagedAudioBuffer: Hashable {
    // MARK: - Properties

    let id: UUID
    let buffer: AVAudioPCMBuffer
    let creationTime: Date
    private(set) var lastUsedTime: Date
    private var useCount: Int = 0

    /// Memory size in bytes - using frameCapacity for worst-case scenario
    var memorySize: Int {
        Int(buffer.frameCapacity * buffer.format.streamDescription.pointee.mBytesPerFrame)
    }

    /// Time since last use
    var idleTime: TimeInterval {
        Date().timeIntervalSince(lastUsedTime)
    }

    /// Usage frequency (uses per second since creation)
    var usageFrequency: Double {
        let lifetime = Date().timeIntervalSince(creationTime)
        return lifetime > 0 ? Double(useCount) / lifetime : 0
    }

    // MARK: - Initialization

    init(buffer: AVAudioPCMBuffer) {
        id = UUID()
        self.buffer = buffer
        creationTime = Date()
        lastUsedTime = creationTime
    }

    // MARK: - Public Methods

    func markUsed() {
        lastUsedTime = Date()
        useCount += 1
    }

    /// Clear buffer contents to free memory
    func clear() {
        guard let channelData = buffer.floatChannelData else { return }

        for channel in 0 ..< Int(buffer.format.channelCount) {
            memset(channelData[channel], 0, Int(buffer.frameCapacity) * MemoryLayout<Float>.size)
        }
        buffer.frameLength = 0
    }

    /// Copy data from another buffer
    func copyFrom(_ other: AVAudioPCMBuffer) {
        guard buffer.format == other.format,
              buffer.frameCapacity >= other.frameLength
        else {
            return
        }

        buffer.frameLength = other.frameLength

        // Copy channel data efficiently using memcpy
        for channel in 0 ..< Int(buffer.format.channelCount) {
            guard let sourceData = other.floatChannelData?[channel],
                  let destData = buffer.floatChannelData?[channel]
            else {
                continue
            }

            memcpy(destData,
                   sourceData,
                   Int(other.frameLength) * MemoryLayout<Float>.size)
        }

        markUsed()
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ManagedAudioBuffer, rhs: ManagedAudioBuffer) -> Bool {
        lhs.id == rhs.id
    }
}
