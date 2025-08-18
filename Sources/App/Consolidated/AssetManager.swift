import Combine
import Foundation
import SwiftUI
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Manages centralized access to all app assets with caching and memory management
class AssetManager {
    // MARK: - Singleton

    /// Shared singleton instance
    static let shared = AssetManager()

    // MARK: - Published Properties

    /// Indicates if all required assets are loaded
    @Published private(set) var isAssetsLoaded = false

    /// Asset loading progress (0.0-1.0)
    @Published private(set) var loadingProgress: Float = 0.0

    // MARK: - Asset Collections

    /// App icons collection
    private var appIcons: [String: UIImage] = [:]

    /// Mood icons collection
    private var moodIcons: [Asset.MoodColor: UIImage] = [:]

    /// Personality type icons collection
    private var personalityIcons: [Asset.PersonalityColor: UIImage] = [:]

    /// Placeholder images collection
    private var placeholderImages: [String: UIImage] = [:]

    /// Background images collection
    private var backgroundImages: [String: UIImage] = [:]

    // MARK: - Color Assets

    /// Brand colors collection
    private var brandColors: [String: Color] = [:]

    /// Mood-based colors collection
    private var moodColors: [Asset.MoodColor: Color] = [:]

    /// Personality type colors collection
    private var personalityColors: [Asset.PersonalityColor: Color] = [:]

    // MARK: - Private Properties

    /// Asset loading queue for thread safety
    private let loadingQueue = DispatchQueue(label: "com.ai-mixtapes.assetmanager", qos: .userInitiated)

    /// Asset loading operation queue for concurrent loading
    private let loadingOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.ai-mixtapes.assetmanager.operations"
        queue.maxConcurrentOperationCount = 4
        return queue
    }()

    /// Memory cache for storing frequently accessed assets
    private let cache = NSCache<NSString, AnyObject>()

    // MARK: - Initialization

    private init() {
        configureCache()
    }

    // MARK: - Asset Loading

    /// Load all required app assets
    func loadAssets() {
        loadingQueue.async { [weak self] in
            guard let self else { return }

            // Load app colors first
            loadBrandColors()
            loadMoodColors()
            loadPersonalityColors()

            // Load icon assets
            loadAppIcons()
            loadMoodIcons()
            loadPersonalityIcons()

            // Load additional assets
            loadPlaceholderImages()
            loadBackgroundImages()

            // Validate loaded assets
            let isValid = Asset.validateAssets()

            DispatchQueue.main.async {
                self.isAssetsLoaded = isValid
                self.loadingProgress = 1.0
            }
        }
    }

    // MARK: - Asset Access Methods

    /// Get app icon by name
    func appIcon(named name: String) -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) as? UIImage {
            return cached
        }

        if let icon = appIcons[name] {
            cache.setObject(icon, forKey: name as NSString)
            return icon
        }

        return nil
    }

    /// Get mood icon for specific mood
    func moodIcon(for mood: Asset.MoodColor) -> UIImage? {
        let key = "mood_\(mood.rawValue)"

        if let cached = cache.object(forKey: key as NSString) as? UIImage {
            return cached
        }

        if let icon = moodIcons[mood] {
            cache.setObject(icon, forKey: key as NSString)
            return icon
        }

        return nil
    }

    /// Get personality icon for specific personality type
    func personalityIcon(for type: Asset.PersonalityColor) -> UIImage? {
        let key = "personality_\(type.rawValue)"

        if let cached = cache.object(forKey: key as NSString) as? UIImage {
            return cached
        }

        if let icon = personalityIcons[type] {
            cache.setObject(icon, forKey: key as NSString)
            return icon
        }

        return nil
    }

    /// Get brand color by name
    func brandColor(named name: String) -> Color {
        if let color = brandColors[name] {
            return color
        }
        return .gray // Fallback color
    }

    /// Get color for specific mood
    func moodColor(for mood: Asset.MoodColor) -> Color {
        if let color = moodColors[mood] {
            return color
        }
        return mood.color // Use default color from Asset enum
    }

    /// Get color for specific personality type
    func personalityColor(for type: Asset.PersonalityColor) -> Color {
        if let color = personalityColors[type] {
            return color
        }
        return type.color // Use default color from Asset enum
    }

    /// Get placeholder image by type
    func placeholder(named name: String) -> UIImage? {
        if let cached = cache.object(forKey: "placeholder_\(name)" as NSString) as? UIImage {
            return cached
        }

        if let image = placeholderImages[name] {
            cache.setObject(image, forKey: "placeholder_\(name)" as NSString)
            return image
        }

        return nil
    }

    /// Get background image by name
    func backgroundImage(named name: String) -> UIImage? {
        if let cached = cache.object(forKey: "background_\(name)" as NSString) as? UIImage {
            return cached
        }

        if let image = backgroundImages[name] {
            cache.setObject(image, forKey: "background_\(name)" as NSString)
            return image
        }

        return nil
    }

    // MARK: - Private Methods

    private func configureCache() {
        // Set reasonable memory limits based on device
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryLimit = Int(Double(totalMemory) * 0.1) // Use 10% of available memory
        cache.totalCostLimit = memoryLimit
    }

    private func loadBrandColors() {
        loadingProgress = 0.1

        for color in Asset.Color.allCases {
            brandColors[color.rawValue] = color.color
        }
    }

    private func loadMoodColors() {
        loadingProgress = 0.2

        for mood in Asset.MoodColor.allCases {
            moodColors[mood] = mood.color
        }
    }

    private func loadPersonalityColors() {
        loadingProgress = 0.3

        for personality in Asset.PersonalityColor.allCases {
            personalityColors[personality] = personality.color
        }
    }

    private func loadAppIcons() {
        loadingProgress = 0.4
        // Load from asset catalog based on naming convention
        if let icon = try? Asset.image(name: "AppIcon") {
            appIcons["default"] = icon
        }
    }

    private func loadMoodIcons() {
        loadingProgress = 0.5

        for mood in Asset.MoodColor.allCases {
            if let icon = try? Asset.image(name: "Mood/\(mood.rawValue)Icon") {
                moodIcons[mood] = icon
            }
        }
    }

    private func loadPersonalityIcons() {
        loadingProgress = 0.6

        for personality in Asset.PersonalityColor.allCases {
            if let icon = try? Asset.image(name: "Personality/\(personality.rawValue)Icon") {
                personalityIcons[personality] = icon
            }
        }
    }

    private func loadPlaceholderImages() {
        loadingProgress = 0.7
        // Load placeholder images from asset catalog
        if let placeholder = try? Asset.image(name: "PlaceholderImage") {
            placeholderImages["default"] = placeholder
        }
    }

    private func loadBackgroundImages() {
        loadingProgress = 0.8
        // Load background images from asset catalog
        if let background = try? Asset.image(name: "Background/Default") {
            backgroundImages["default"] = background
        }
    }

    // MARK: - Memory Management

    /// Clear all cached assets to free memory
    func clearCache() {
        cache.removeAllObjects()
    }

    /// Clear specific cached asset
    func clearCache(for key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    // MARK: - Asset Generation

    /// Generate placeholder image with specific size and color
    #if canImport(UIKit)
        func generatePlaceholder(size: CGSize, color: Color) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                let cgColor = UIColor(color).cgColor
                context.cgContext.setFillColor(cgColor)
                context.cgContext.fill(CGRect(origin: .zero, size: size))
            }
        }

    #elseif canImport(AppKit)
        func generatePlaceholder(size: CGSize, color: Color) -> NSImage {
            let image = NSImage(size: size)
            image.lockFocus()

            let cgColor = NSColor(color).cgColor
            let context = NSGraphicsContext.current!.cgContext
            context.setFillColor(cgColor)
            context.fill(CGRect(origin: .zero, size: size))

            image.unlockFocus()
            return image
        }
    #endif

    /// Generate gradient background image
    #if canImport(UIKit)
        func generateGradientBackground(colors: [Color], size: CGSize) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                let cgColors = colors.map { UIColor($0).cgColor }
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: cgColors as CFArray,
                                          locations: nil)!

                let startPoint = CGPoint(x: 0, y: 0)
                let endPoint = CGPoint(x: size.width, y: size.height)

                context.cgContext.drawLinearGradient(gradient,
                                                     start: startPoint,
                                                     end: endPoint,
                                                     options: [])
            }
        }

    #elseif canImport(AppKit)
        func generateGradientBackground(colors: [Color], size: CGSize) -> NSImage {
            let image = NSImage(size: size)
            image.lockFocus()

            let cgColors = colors.map { NSColor($0).cgColor }
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: cgColors as CFArray,
                                      locations: nil)!

            let context = NSGraphicsContext.current!.cgContext
            let startPoint = CGPoint(x: 0, y: 0)
            let endPoint = CGPoint(x: size.width, y: size.height)

            context.drawLinearGradient(gradient,
                                       start: startPoint,
                                       end: endPoint,
                                       options: [])

            image.unlockFocus()
            return image
        }
    #endif
}
