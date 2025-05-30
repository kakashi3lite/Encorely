import Foundation
import AVFoundation
import MusicKit
import Combine

/// Extension to PlayerManager to handle MusicKit functionality
extension PlayerManager {
    /// Configure the player for MusicKit playback
    func configureMusicKitPlayback() {
        // Set up MusicKit player observation
        setupMusicPlayerObservation()
        
        // Set audio session category for MusicKit
        configureAudioSession()
    }
    
    private func setupMusicPlayerObservation() {
        // Observe MusicPlayer state changes
        NotificationCenter.default.publisher(for: MusicPlayer.stateDidChange)
            .sink { [weak self] notification in
                guard let self = self else { return }
                self.handleMusicPlayerStateChange()
            }
            .store(in: &cancellables)
        
        // Observe queue changes
        NotificationCenter.default.publisher(for: MusicPlayer.queueDidChange)
            .sink { [weak self] notification in
                guard let self = self else { return }
                self.handleQueueChange()
            }
            .store(in: &cancellables)
    }
    
    private func handleMusicPlayerStateChange() {
        let player = MusicPlayer.shared
        
        // Update playing state
        isPlaying.value = player.state == .playing
        
        // Update current song info
        if let currentEntry = player.queue.currentEntry {
            if case .song(let song) = currentEntry.item {
                currentSongName.name = song.title
            }
        } else {
            currentSongName.name = "Not Playing"
        }
    }
    
    private func handleQueueChange() {
        let queue = MusicPlayer.shared.queue
        
        // Update player items
        let items = queue.entries.compactMap { entry -> AVPlayerItem? in
            guard case .song(let song) = entry.item,
                  let url = song.url else { return nil }
            return AVPlayerItem(url: url)
        }
        currentPlayerItems.items = items
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NotificationCenter.default.post(
                name: .audioServiceError,
                object: AppError.audioUnavailable
            )
        }
    }
    
    // MARK: - Playback Control
    
    /// Play a song from MusicKit
    func playMusicKitSong(_ song: Song) async throws {
        let player = MusicPlayer.shared
        
        // Create a queue with the selected song
        let queueEntry = MusicPlayer.Queue.Entry(song: song)
        try await player.queue.insert(queueEntry, position: .tail)
        
        // Start playback
        try await player.play()
    }
    
    /// Play a playlist from MusicKit
    func playMusicKitPlaylist(_ playlist: Playlist) async throws {
        let player = MusicPlayer.shared
        
        // Create queue entries from playlist items
        let entries = playlist.items.map { MusicPlayer.Queue.Entry(item: $0) }
        
        // Set the queue and start playback
        try await player.queue.insert(entries, position: .tail)
        try await player.play()
    }
    
    /// Toggle play/pause
    func togglePlayback() async throws {
        let player = MusicPlayer.shared
        
        if player.state == .playing {
            try await player.pause()
        } else {
            try await player.play()
        }
    }
    
    /// Skip to next track
    func skipToNextTrack() async throws {
        try await MusicPlayer.shared.skipToNextEntry()
    }
    
    /// Skip to previous track
    func skipToPreviousTrack() async throws {
        try await MusicPlayer.shared.skipToPreviousEntry()
    }
}
