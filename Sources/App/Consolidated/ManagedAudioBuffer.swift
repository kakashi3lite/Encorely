import Foundation
import AVFoundation

/// Managed wrapper for AVAudioPCMBuffer with memory tracking
final class ManagedAudioBuffer: Hashable {
    let id: UUID
    let buffer: AVAudioPCMBuffer?
    let creationTime: Date
    private(set) var lastUsedTime: Date
    
    var memorySize: Int {
        guard let buffer = buffer else { return 0 }
        return Int(buffer.frameLength * buffer.format.streamDescription.pointee.mBytesPerFrame)
    }
    
    var idleTime: TimeInterval {
        return Date().timeIntervalSince(lastUsedTime)
    }
    
    init(buffer: AVAudioPCMBuffer) {
        self.id = UUID()
        self.buffer = buffer
        self.creationTime = Date()
        self.lastUsedTime = creationTime
    }
    
    func markUsed() {
        lastUsedTime = Date()
    }
    
    func copyFrom(_ other: AVAudioPCMBuffer) {
        guard let buffer = self.buffer,
              buffer.format == other.format,
              buffer.frameCapacity >= other.frameLength else {
            return
        }
        
        buffer.frameLength = other.frameLength
        
        // Copy channel data
        for channel in 0..<Int(buffer.format.channelCount) {
            guard let sourceData = other.floatChannelData?[channel],
                  let destData = buffer.floatChannelData?[channel] else {
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
        return lhs.id == rhs.id
    }
}
