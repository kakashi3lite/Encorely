//
//  AIUtilities.swift
//  AI-Mixtapes
//
//  Created by Claude AI on 05/18/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

// MARK: - Error Handling

enum AIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case audioLoadFailed
    case imageLoadFailed
    case songNotReachable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL provided"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .audioLoadFailed: return "Failed to load audio file"
        case .imageLoadFailed: return "Failed to load cover art image"
        case .songNotReachable: return "Song URL is not reachable"
        }
    }
}

// MARK: - Image Cache

private let imageCache = NSCache<NSString, UIImage>()

// MARK: - Utility Functions

/// Get cover art image from URL with caching
func getCoverArtImage(url: URL) -> UIImage {
    let cacheKey = url.absoluteString as NSString
    
    // Check cache first
    if let cachedImage = imageCache.object(forKey: cacheKey) {
        return cachedImage
    }
    
    // Load synchronously (for compatibility with existing code)
    let semaphore = DispatchSemaphore(value: 0)
    var resultImage = UIImage(systemName: "music.note") ?? UIImage()
    
    Task {
        do {
            let image = try await loadImageAsync(from: url)
            imageCache.setObject(image, forKey: cacheKey)
            resultImage = image
        } catch {
            print("Failed to load image: \(error)")
        }
        semaphore.signal()
    }
    
    semaphore.wait()
    return resultImage
}

/// Async image loading helper
private func loadImageAsync(from url: URL) async throws -> UIImage {
    let (data, response) = try await URLSession.shared.data(from: url)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw AIError.networkError(URLError(.badServerResponse))
    }
    
    guard let image = UIImage(data: data) else {
        throw AIError.imageLoadFailed
    }
    
    return image
}

/// Create array of AVPlayerItems from songs
func createArrayOfPlayerItems(songs: [Song]) -> [AVPlayerItem] {
    return songs.compactMap { song in
        let url = song.wrappedUrl
        guard url.absoluteString != "" else { return nil }
        
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        // Add metadata for identification
        let metadata = AVMutableMetadataItem()
        metadata.identifier = .commonIdentifierTitle
        metadata.value = song.wrappedName as NSString
        item.externalMetadata = [metadata]
        
        return item
    }
}

/// Load player items into AVQueuePlayer
func loadPlayer(arrayOfPlayerItems: [AVPlayerItem], player: AVQueuePlayer) {
    // Remove all existing items
    player.removeAllItems()
    
    // Add new items
    for item in arrayOfPlayerItems {
        player.insert(item, after: nil)
    }
}

/// Skip back to previous song
func skipBack(currentPlayerItems: [AVPlayerItem], currentSongName: String, queuePlayer: AVQueuePlayer, isPlaying: Bool) {
    guard let currentItem = queuePlayer.currentItem else { return }
    
    // Find current item index
    let currentIndex = currentPlayerItems.firstIndex(of: currentItem) ?? 0
    
    if currentIndex > 0 {
        // Go to previous item
        let previousItem = currentPlayerItems[currentIndex - 1]
        
        // Remove all items and reload from previous
        queuePlayer.removeAllItems()
        
        // Add items starting from previous
        for item in currentPlayerItems[currentIndex - 1...] {
            queuePlayer.insert(item, after: nil)
        }
        
        // Play if was playing
        if isPlaying {
            queuePlayer.play()
        }
    } else {
        // Already at first song, restart current
        currentItem.seek(to: CMTime.zero)
        if isPlaying {
            queuePlayer.play()
        }
    }
}

/// Get song name from AVPlayerItem
func getItemName(playerItem: AVPlayerItem?) -> String {
    guard let item = playerItem else { return "Not Playing" }
    
    // Try to get from external metadata first
    for metadata in item.externalMetadata {
        if metadata.identifier == .commonIdentifierTitle,
           let title = metadata.value as? String {
            return title
        }
    }
    
    // Fallback to asset metadata
    if let asset = item.asset as? AVURLAsset {
        let fileName = asset.url.lastPathComponent
        return fileName.replacingOccurrences(of: ".\(asset.url.pathExtension)", with: "")
    }
    
    return "Unknown Song"
}

/// Check if song URL is reachable
func checkSongUrlIsReachable(song: Song) -> Bool {
    let url = song.wrappedUrl
    
    // Basic URL validation
    guard url.absoluteString != "",
          url.scheme != nil else {
        return false
    }
    
    // For file URLs, check if file exists
    if url.isFileURL {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    // For remote URLs, assume reachable (avoid blocking main thread)
    // In production, you might want to cache reachability status
    return true
}

/// Async URL reachability check (for background validation)
func checkUrlReachability(url: URL) async throws -> Bool {
    var request = URLRequest(url: url)
    request.httpMethod = "HEAD"
    request.timeoutInterval = 5.0
    
    do {
        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    } catch {
        throw AIError.networkError(error)
    }
}

// MARK: - Environment Configuration

/**
 * Environment Variables (.env file)
 * 
 * Create a .env file in your project root with:
 * SPOTIFY_CLIENT_ID=your_spotify_client_id
 * SPOTIFY_CLIENT_SECRET=your_spotify_client_secret
 * 
 * ⚠️ WARNING: Never commit .env files to version control!
 * Add .env to your .gitignore file to prevent accidental exposure.
 * For production builds, use Xcode build configurations or environment variables.
 */

struct EnvironmentConfig {
    static let spotifyClientId = ProcessInfo.processInfo.environment["SPOTIFY_CLIENT_ID"] ?? ""
    static let spotifyClientSecret = ProcessInfo.processInfo.environment["SPOTIFY_CLIENT_SECRET"] ?? ""
}