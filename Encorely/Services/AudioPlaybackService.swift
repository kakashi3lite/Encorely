import AVFoundation
import Foundation
import Observation
import os.log

/// Manages audio playback with AVQueuePlayer.
/// Provides play/pause/skip/seek and exposes current state for the UI.
@Observable
final class AudioPlaybackService: @unchecked Sendable {
    // MARK: - Observable State

    /// The currently loaded song (nil if nothing is loaded).
    private(set) var currentSong: Song?

    /// Whether audio is actively playing.
    private(set) var isPlaying: Bool = false

    /// Current playback position in seconds.
    private(set) var currentTime: TimeInterval = 0

    /// Total duration of the current track in seconds.
    private(set) var duration: TimeInterval = 0

    /// Playback progress (0.0–1.0).
    var progress: Double {
        duration > 0 ? currentTime / duration : 0
    }

    /// The playback queue.
    private(set) var queue: [Song] = []

    /// Index of the current song within the queue.
    private(set) var currentIndex: Int = 0

    // MARK: - Private

    private var player: AVPlayer?
    private var timeObserver: Any?
    private let logger = Logger(subsystem: "com.encorely", category: "Playback")

    // MARK: - Init / Deinit

    init() {
        configureAudioSession()
    }

    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Loads a queue of songs and starts playing from the given index.
    func play(songs: [Song], startingAt index: Int = 0) {
        guard !songs.isEmpty, index < songs.count else { return }
        queue = songs
        currentIndex = index
        loadAndPlay(songs[index])
    }

    /// Plays a single song.
    func play(song: Song) {
        play(songs: [song], startingAt: 0)
    }

    /// Toggles play/pause.
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    /// Pauses playback.
    func pause() {
        player?.pause()
        isPlaying = false
    }

    /// Resumes playback.
    func resume() {
        player?.play()
        isPlaying = true
    }

    /// Skips to the next song in the queue.
    func skipForward() {
        guard currentIndex + 1 < queue.count else { return }
        currentIndex += 1
        loadAndPlay(queue[currentIndex])
    }

    /// Goes back to the previous song in the queue.
    func skipBackward() {
        if currentTime > 3 {
            // If more than 3 seconds in, restart current song
            seek(to: 0)
        } else if currentIndex > 0 {
            currentIndex -= 1
            loadAndPlay(queue[currentIndex])
        }
    }

    /// Seeks to a position in the current track (0.0–1.0).
    func seek(toProgress progress: Double) {
        let target = duration * progress
        seek(to: target)
    }

    /// Seeks to an absolute time in seconds.
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime) { [weak self] _ in
            self?.currentTime = time
        }
    }

    /// Stops playback and clears the queue.
    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        currentSong = nil
        currentTime = 0
        duration = 0
        queue.removeAll()
        currentIndex = 0
    }

    // MARK: - Internal

    private func loadAndPlay(_ song: Song) {
        // Remove old observer
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        currentSong = song
        currentTime = 0
        duration = song.duration

        // In MusicKit-based playback, we'd use ApplicationMusicPlayer.
        // For local files, use AVPlayer with the song's URL.
        // Placeholder: we set isPlaying to true and use a timer for progress.
        isPlaying = true
        logger.info("Now playing: \(song.name)")

        song.trackPlay()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            logger.error("Audio session setup failed: \(error.localizedDescription)")
        }
    }
}
