import Foundation
import AVFoundation

/// Wraps an AVAudioPCMBuffer with management metadata
struct ManagedAudioBuffer: Hashable {
    let buffer: AVAudioPCMBuffer
    let size: Int
    var lastUsed: Date
    
    init(buffer: AVAudioPCMBuffer, size: Int) {
        self.buffer = buffer
        self.size = size
        self.lastUsed = Date()
    }
    
    // MARK: - Hashable Conformance
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(buffer))
    }
    
    static func == (lhs: ManagedAudioBuffer, rhs: ManagedAudioBuffer) -> Bool {
        return lhs.buffer === rhs.buffer
    }
}