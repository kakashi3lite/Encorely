import AVFoundation
import Foundation

/// Wraps an AVAudioPCMBuffer with management metadata
struct ManagedAudioBuffer: Hashable {
    let buffer: AVAudioPCMBuffer
    let size: Int
    var lastUsed: Date

    init(buffer: AVAudioPCMBuffer, size: Int) {
        self.buffer = buffer
        self.size = size
        lastUsed = Date()
    }

    // MARK: - Hashable Conformance

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(buffer))
    }

    static func == (lhs: ManagedAudioBuffer, rhs: ManagedAudioBuffer) -> Bool {
        lhs.buffer === rhs.buffer
    }
}
