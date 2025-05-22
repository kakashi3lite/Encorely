//
//  PlayerManager.swift
//  AI-Mixtapes
//
//  Created by Claude AI on 05/18/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import AVFoundation
import Combine

/// Manages audio playback and session handling for the app
final class PlayerManager {
    static let shared = PlayerManager()
    
    // Main player and observers
    private(set) var queuePlayer: AVQueuePlayer
    private(set) var statusObserver: PlayerStatusObserver
    private(set) var itemObserver: PlayerItemObserver
    
    // State publishers
    @Published private(set) var currentPlayerItems = CurrentPlayerItems()
    @Published private(set) var currentSongName = CurrentSongName()
    @Published private(set) var isPlaying = IsPlaying()
    
    private var playerItemObservation: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()
    private var memoryWarningObserver: NSObjectProtocol?
    
    private init() {
        // Initialize player components
        queuePlayer = AVQueuePlayer()
        statusObserver = PlayerStatusObserver()
        itemObserver = PlayerItemObserver()
        
        setupAudioSession()
        setupObservers()
        setupMemoryWarningObserver()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NotificationCenter.default.post(
                name: .audioServiceError,
                object: AppError.audioUnavailable
            )
        }
    }
    
    private func setupObservers() {
        // Observe player item changes
        playerItemObservation = queuePlayer.observe(\.currentItem) { [weak self] player, _ in
            guard let self = self else { return }
            if let item = player.currentItem {
                self.itemObserver.observe(item)
                if let url = (item as? AVURLAsset)?.url {
                    self.currentSongName.name = url.lastPathComponent
                }
            } else {
                self.currentSongName.name = "Not Playing"
            }
        }
        
        // Handle interruptions
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleAudioInterruption(notification)
            }
            .store(in: &cancellables)
        
        // Handle route changes
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                self?.handleRouteChange(notification)
            }
            .store(in: &cancellables)
    }
    
    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: .performanceMemoryWarning,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        cleanupResources()
    }
    
    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            queuePlayer.pause()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                queuePlayer.play()
            }
        @unknown default:
            break
        }
    }
    
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            queuePlayer.pause()
        default:
            break
        }
    }
    
    private func cleanupResources() {
        NotificationCenter.default.removeObserver(self)
        currentPlayerItem?.asset.cancelLoading()
        queue.async { [weak self] in
            self?.playbackCache.removeAllObjects()
        }
    }

    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        cleanupResources()
    }
}

// MARK: - Public Interface

extension PlayerManager {
    func loadItems(_ items: [AVPlayerItem]) throws {
        guard !items.isEmpty else {
            throw AppError.audioLoadFailed(nil)
        }
        
        currentPlayerItems.items = items
        queuePlayer.removeAllItems()
        items.forEach { queuePlayer.insert($0, after: nil) }
    }
    
    func play() {
        queuePlayer.play()
        isPlaying.value = true
    }
    
    func play(_ track: Track) {
        PerformanceMonitor.shared.startTracking("track_playback_\(track.id)")
        queuePlayer.play()
        isPlaying.value = true
    }
    
    func pause() {
        queuePlayer.pause()
        isPlaying.value = false
    }
    
    func stop() {
        if let currentTrack = currentTrack {
            PerformanceMonitor.shared.endTracking("track_playback_\(currentTrack.id)")
        }
        queuePlayer.pause()
        isPlaying.value = false
    }
    
    func skip() {
        queuePlayer.advanceToNextItem()
    }
}

// MARK: - Supporting Types

class CurrentPlayerItems: ObservableObject {
    @Published var items: [AVPlayerItem] = []
}

class CurrentSongName: ObservableObject {
    @Published var name: String = "Not Playing"
}

class IsPlaying: ObservableObject {
    @Published var value: Bool = false
}

// MARK: - Notification Names

extension Notification.Name {
    static let playerTimeDidUpdate = Notification.Name("PlayerTimeDidUpdate")
}

// MARK: - Observers

/// Observes player status changes
class PlayerStatusObserver: ObservableObject {
    @Published var playerStatus: AVPlayer.Status = .unknown
    private var observation: NSKeyValueObservation?
    
    func observe(_ player: AVQueuePlayer) {
        observation = player.observe(\.status, options: [.new]) { [weak self] _, change in
            DispatchQueue.main.async {
                self?.playerStatus = player.status
            }
        }
    }
}

/// Observes current item changes
class PlayerItemObserver: ObservableObject {
    @Published var currentItem: AVPlayerItem?
    private var observation: NSKeyValueObservation?
    
    func observe(_ player: AVQueuePlayer) {
        observation = player.observe(\.currentItem, options: [.new]) { [weak self] _, change in
            DispatchQueue.main.async {
                self?.currentItem = player.currentItem
            }
        }
    }
}