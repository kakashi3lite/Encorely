import Foundation
import Observation

/// Provides formatted playback state for the player UI.
@Observable
final class PlayerViewModel {
    private let playbackService: AudioPlaybackService

    init(playbackService: AudioPlaybackService) {
        self.playbackService = playbackService
    }

    var songTitle: String {
        playbackService.currentSong?.name ?? "Not Playing"
    }

    var artistName: String {
        playbackService.currentSong?.artist ?? ""
    }

    var isPlaying: Bool { playbackService.isPlaying }

    var progress: Double { playbackService.progress }

    var currentTimeFormatted: String {
        formatTime(playbackService.currentTime)
    }

    var remainingTimeFormatted: String {
        "-\(formatTime(playbackService.duration - playbackService.currentTime))"
    }

    func togglePlayPause() { playbackService.togglePlayPause() }
    func skipForward() { playbackService.skipForward() }
    func skipBackward() { playbackService.skipBackward() }
    func seek(to progress: Double) { playbackService.seek(toProgress: progress) }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(max(0, seconds)) / 60
        let secs = Int(max(0, seconds)) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
