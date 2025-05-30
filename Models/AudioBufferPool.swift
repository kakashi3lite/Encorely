import Foundation
import AVFoundation

/// A managed audio buffer that can be pooled and reused
class ManagedAudioBuffer: Hashable {
    let buffer: AVAudioPCMBuffer
    private let id = UUID()
    
    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }
    
    func copyFrom(_ sourceBuffer: AVAudioPCMBuffer) {
        guard let sourceChannelData = sourceBuffer.floatChannelData,
              let targetChannelData = buffer.floatChannelData else {
            return
        }
        
        let framesToCopy = min(sourceBuffer.frameLength, buffer.frameCapacity)
        let bytesToCopy = Int(framesToCopy) * MemoryLayout<Float>.size
        
        for channel in 0..<Int(buffer.format.channelCount) {
            memcpy(targetChannelData[channel], sourceChannelData[channel], bytesToCopy)
        }
        
        buffer.frameLength = framesToCopy
    }
    
    static func == (lhs: ManagedAudioBuffer, rhs: ManagedAudioBuffer) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// A pool for managing and reusing audio buffers
class AudioBufferPool {
    private var availableBuffers: [ManagedAudioBuffer] = []
    private var usedBuffers: Set<ManagedAudioBuffer> = []
    private let maxBuffers: Int
    private let bufferSize: UInt32
    private let queue = DispatchQueue(label: "audio.buffer.pool", attributes: .concurrent)
    
    init(maxBuffers: Int, bufferSize: UInt32) {
        self.maxBuffers = maxBuffers
        self.bufferSize = bufferSize
        
        // Pre-allocate buffers
        for _ in 0..<maxBuffers {
            if let buffer = createBuffer() {
                availableBuffers.append(buffer)
            }
        }
    }
    
    func getBuffer() -> ManagedAudioBuffer? {
        return queue.sync(flags: .barrier) {
            guard let buffer = availableBuffers.popLast() else {
                // Try to create a new buffer if under limit
                if usedBuffers.count < maxBuffers {
                    return createBuffer()
                }
                return nil
            }
            
            usedBuffers.insert(buffer)
            return buffer
        }
    }
    
    func returnBuffer(_ buffer: ManagedAudioBuffer) {
        queue.async(flags: .barrier) {
            self.usedBuffers.remove(buffer)
            self.availableBuffers.append(buffer)
        }
    }
    
    func releaseAllBuffers() {
        queue.async(flags: .barrier) {
            self.availableBuffers.removeAll()
            self.usedBuffers.removeAll()
        }
    }
    
    func reducePoolSize() {
        queue.async(flags: .barrier) {
            // Keep only half the buffers during memory pressure
            let keepCount = self.maxBuffers / 2
            if self.availableBuffers.count > keepCount {
                self.availableBuffers.removeFirst(self.availableBuffers.count - keepCount)
            }
        }
    }
    
    private func createBuffer() -> ManagedAudioBuffer? {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize) else {
            return nil
        }
        
        return ManagedAudioBuffer(buffer: buffer)
    }
}
