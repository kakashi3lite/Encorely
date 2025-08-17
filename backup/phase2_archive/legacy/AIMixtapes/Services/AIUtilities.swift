//
//  AIUtilities.swift
//  AI-Mixtapes
//
//  Created by Claude AI on 05/18/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Accelerate
import AVFoundation
import CoreML
import Foundation
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
        case .invalidURL: "Invalid URL provided"
        case let .networkError(error): "Network error: \(error.localizedDescription)"
        case .audioLoadFailed: "Failed to load audio file"
        case .imageLoadFailed: "Failed to load cover art image"
        case .songNotReachable: "Song URL is not reachable"
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
          httpResponse.statusCode == 200
    else {
        throw AIError.networkError(URLError(.badServerResponse))
    }

    guard let image = UIImage(data: data) else {
        throw AIError.imageLoadFailed
    }

    return image
}

/// Create array of AVPlayerItems from songs
func createArrayOfPlayerItems(songs: [Song]) -> [AVPlayerItem] {
    songs.compactMap { song in
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
func skipBack(currentPlayerItems: [AVPlayerItem], currentSongName _: String, queuePlayer: AVQueuePlayer,
              isPlaying: Bool)
{
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
           let title = metadata.value as? String
        {
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
          url.scheme != nil
    else {
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

enum EnvironmentConfig {
    static let spotifyClientId = ProcessInfo.processInfo.environment["SPOTIFY_CLIENT_ID"] ?? ""
    static let spotifyClientSecret = ProcessInfo.processInfo.environment["SPOTIFY_CLIENT_SECRET"] ?? ""
}

// MARK: - AI Utilities

/// Utilities for optimizing AI operations and managing resources
enum AIUtilities {
    // MARK: - Background Processing

    /// Process ML operations in background with proper QoS
    static func processInBackground<T>(_ operation: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try operation()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Memory Management

    /// Cache for ML model outputs
    private static var modelCache = NSCache<NSString, AnyObject>()

    /// Configure cache limits based on device capabilities
    static func configureCacheLimit() {
        modelCache.countLimit = 100
        modelCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    /// Cache ML model output with expiration
    static func cacheModelOutput(_ output: some AnyObject, forKey key: String, expirationInterval: TimeInterval = 300) {
        let expirationDate = Date().addingTimeInterval(expirationInterval)
        let cacheItem = CacheItem(value: output, expirationDate: expirationDate)
        modelCache.setObject(cacheItem, forKey: key as NSString)
    }

    /// Retrieve cached ML model output if valid
    static func getCachedModelOutput<T: AnyObject>(forKey key: String) -> T? {
        guard let cacheItem = modelCache.object(forKey: key as NSString) as? CacheItem,
              cacheItem.expirationDate > Date(),
              let value = cacheItem.value as? T
        else {
            return nil
        }
        return value
    }

    // MARK: - Performance Optimization

    /// Batch process multiple inputs for better performance
    static func batchProcess<T, U>(_ inputs: [T], batchSize: Int = 10,
                                   operation: @escaping ([T]) throws -> [U]) async throws -> [U]
    {
        let batches = stride(from: 0, to: inputs.count, by: batchSize).map {
            Array(inputs[$0 ..< min($0 + batchSize, inputs.count)])
        }

        var results: [U] = []
        for batch in batches {
            let batchResults = try await processInBackground {
                try operation(batch)
            }
            results.append(contentsOf: batchResults)
        }
        return results
    }

    /// Optimize audio buffer for ML processing
    static func optimizeAudioBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let optimizedBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format,
                                                     frameCapacity: buffer.frameLength)
        else {
            return nil
        }

        // Normalize and optimize audio data
        let channels = UnsafeBufferPointer(start: buffer.floatChannelData,
                                           count: Int(buffer.format.channelCount))
        let optimizedChannels = UnsafeBufferPointer(start: optimizedBuffer.floatChannelData,
                                                    count: Int(optimizedBuffer.format.channelCount))

        for (source, destination) in zip(channels, optimizedChannels) {
            // Apply normalization
            var normalizedData = [Float](repeating: 0,
                                         count: Int(buffer.frameLength))
            vDSP_vabs(source, 1,
                      &normalizedData, 1,
                      vDSP_Length(buffer.frameLength))

            var maximumValue: Float = 0
            vDSP_maxv(normalizedData, 1,
                      &maximumValue,
                      vDSP_Length(buffer.frameLength))

            if maximumValue > 0 {
                var scalar = 1.0 / maximumValue
                vDSP_vsmul(normalizedData, 1,
                           &scalar,
                           destination, 1,
                           vDSP_Length(buffer.frameLength))
            }
        }

        optimizedBuffer.frameLength = buffer.frameLength
        return optimizedBuffer
    }

    // MARK: - Resource Management

    /// Monitor and manage ML resource usage
    static func monitorResourceUsage() -> ResourceMetrics {
        var metrics = ResourceMetrics()

        // Memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }

        if kerr == KERN_SUCCESS {
            metrics.memoryUsage = Double(info.resident_size) / 1024.0 / 1024.0
        }

        // CPU usage
        var thread_list: thread_act_array_t?
        var thread_count: mach_msg_type_number_t = 0
        let thread_info_count = mach_msg_type_number_t(THREAD_INFO_MAX)
        var thread_data = thread_basic_info()
        var thread_info_out = mach_msg_type_number_t(thread_info_count)

        if task_threads(mach_task_self_, &thread_list, &thread_count) == KERN_SUCCESS {
            for i in 0 ..< thread_count {
                if thread_info(thread_list![Int(i)],
                               thread_flavor_t(THREAD_BASIC_INFO),
                               UnsafeMutablePointer<integer_t>(mutating: &thread_data),
                               &thread_info_out) == KERN_SUCCESS
                {
                    let usage = (Double(thread_data.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
                    metrics.cpuUsage += usage
                }
            }
        }

        if let thread_list {
            vm_deallocate(mach_task_self_,
                          vm_address_t(UnsafePointer(thread_list).pointee),
                          vm_size_t(thread_count) * vm_size_t(MemoryLayout<thread_t>.size))
        }

        return metrics
    }
}

// MARK: - Supporting Types

/// Cache item with expiration
private class CacheItem {
    let value: AnyObject
    let expirationDate: Date

    init(value: AnyObject, expirationDate: Date) {
        self.value = value
        self.expirationDate = expirationDate
    }
}

/// Resource usage metrics
struct ResourceMetrics {
    var memoryUsage: Double = 0 // In MB
    var cpuUsage: Double = 0 // In percentage

    var description: String {
        """
        Resource Usage:
        - Memory: \(String(format: "%.1f", memoryUsage))MB
        - CPU: \(String(format: "%.1f", cpuUsage))%
        """
    }
}
