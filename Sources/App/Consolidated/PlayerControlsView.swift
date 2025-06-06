import SwiftUI
import AVFoundation

struct PlayerControlsView: View {
    // MARK: - Properties
    @ObservedObject var player: AVQueuePlayer
    @ObservedObject var mcpService = MCPSocketService()
    
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isSeeking = false
    @State private var seekTime: Double = 0
    @State private var volume: Double = 1.0
    @State private var isMuted = false
    
    private let timeObserver: Any?
    private let seekDebouncer = Debouncer(delay: 0.1)
    
    // MARK: - Initialization
    init(player: AVQueuePlayer) {
        self.player = player
        self.timeObserver = setupTimeObserver()
        
        // Initialize player state
        if let currentItem = player.currentItem {
            self.duration = currentItem.duration.seconds
            self.isPlaying = player.rate > 0
            self.volume = Double(player.volume)
        }
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 16) {
            // Time labels
            HStack {
                Text(timeString(from: currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(timeString(from: duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Progress slider
            Slider(
                value: Binding(
                    get: { isSeeking ? seekTime : currentTime },
                    set: { newValue in
                        seekTime = newValue
                        isSeeking = true
                        seekDebouncer.debounce {
                            seek(to: newValue)
                            isSeeking = false
                        }
                    }
                ),
                in: 0...max(duration, 1)
            )
            .accentColor(.primary)
            
            // Playback controls
            HStack(spacing: 24) {
                // Previous track button
                Button(action: previousTrack) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .disabled(player.currentItem == nil)
                
                // Play/Pause button
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                }
                .disabled(player.currentItem == nil)
                
                // Next track button
                Button(action: nextTrack) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .disabled(player.currentItem == nil)
            }
            
            // Volume control
            HStack(spacing: 12) {
                // Mute button
                Button(action: toggleMute) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.body)
                }
                
                // Volume slider
                Slider(
                    value: $volume,
                    in: 0...1,
                    step: 0.01,
                    onEditingChanged: { _ in
                        updateVolume()
                    }
                )
                .accentColor(.primary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .onChange(of: mcpService.playerState) { newState in
            guard let newState = newState else { return }
            
            switch newState.type {
            case "togglePlayback":
                togglePlayback()
            case "seek":
                if let time = newState.time {
                    seek(to: time)
                }
            case "volume":
                if let level = newState.level {
                    volume = level
                    updateVolume()
                }
            case "toggleMute":
                toggleMute()
            default:
                break
            }
        }
        .onAppear {
            mcpService.connect()
        }
        .onDisappear {
            mcpService.disconnect()
        }
    }
    
    // MARK: - Private Methods
    private func setupTimeObserver() -> Any {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        return player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
            if let currentItem = player.currentItem {
                duration = currentItem.duration.seconds
                isPlaying = player.rate > 0
            }
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        mcpService.emitPlayerTogglePlayback()
    }
    
    private func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime) { _ in
            currentTime = time
            mcpService.emitPlayerSeek(time: time)
        }
    }
    
    private func previousTrack() {
        // Implement previous track logic
    }
    
    private func nextTrack() {
        // Implement next track logic
    }
    
    private func toggleMute() {
        isMuted.toggle()
        if isMuted {
            player.volume = 0
        } else {
            player.volume = Float(volume)
        }
        mcpService.emitPlayerToggleMute()
    }
    
    private func updateVolume() {
        player.volume = Float(volume)
        mcpService.emitPlayerVolume(level: volume)
    }
    
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

private class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func debounce(_ block: @escaping () -> Void) {
        workItem?.cancel()
        let newWorkItem = DispatchWorkItem(block: block)
        workItem = newWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: newWorkItem)
    }
}
