import SwiftUI
import UIKit

/// Asset loading error types
public enum AssetError: LocalizedError {
    case missingImage(String)
    case missingColor(String)

    public var errorDescription: String? {
        switch self {
        case let .missingImage(name):
            "Missing image asset: \(name)"
        case let .missingColor(name):
            "Missing color asset: \(name)"
        }
    }
}

/// Provides type-safe access to app assets
public enum Asset {
    /// App images
    public enum Image: String, CaseIterable {
        case launchIcon = "LaunchIcon"

        /// Get a UIImage for this asset
        var uiImage: UIKit.UIImage {
            guard let image = UIKit.UIImage(named: rawValue) else {
                assertionFailure("Missing image asset: \(rawValue)")
                return UIKit.UIImage() // Return empty image in release builds
            }
            return image
        }

        /// Get a SwiftUI Image for this asset
        var image: SwiftUI.Image {
            SwiftUI.Image(rawValue)
        }
    }

    /// App colors
    public enum Color: String, CaseIterable {
        case appPrimary
        case appSecondary
        case background

        /// Get a UIColor for this asset
        var uiColor: UIKit.UIColor {
            guard let color = UIKit.UIColor(named: rawValue) else {
                assertionFailure("Missing color asset: \(rawValue)")
                return .clear // Return clear color in release builds
            }
            return color
        }

        /// Get a SwiftUI Color for this asset
        var color: SwiftUI.Color {
            SwiftUI.Color(rawValue)
        }
    }

    /// Mood-based colors
    public enum MoodColor: String, CaseIterable {
        case angry = "Angry"
        case energetic = "Energetic"
        case focused = "Focused"
        case happy = "Happy"
        case melancholic = "Melancholic"
        case relaxed = "Relaxed"

        /// Get a UIColor for this mood
        public var uiColor: UIKit.UIColor {
            guard let color = UIKit.UIColor(named: "Mood/\(rawValue)") else {
                assertionFailure("Missing mood color asset: \(rawValue)")
                return .clear // Return clear color in release builds
            }
            return color
        }

        /// Get a SwiftUI Color for this mood
        public var color: SwiftUI.Color {
            SwiftUI.Color("Mood/\(rawValue)")
        }

        /// Get color with specified opacity
        public func withOpacity(_ opacity: Double) -> SwiftUI.Color {
            color.opacity(opacity)
        }

        /// Get default color when asset is missing
        public static var defaultColor: SwiftUI.Color {
            .gray
        }
    }

    /// Personality-based colors
    public enum PersonalityColor: String, CaseIterable {
        case curator = "Curator"
        case enthusiast = "Enthusiast"
        case explorer = "Explorer"

        /// Get a UIColor for this personality
        var uiColor: UIKit.UIColor {
            guard let color = UIKit.UIColor(named: "Personality/\(rawValue)") else {
                assertionFailure("Missing personality color asset: \(rawValue)")
                return .clear // Return clear color in release builds
            }
            return color
        }

        /// Get a SwiftUI Color for this personality
        var color: SwiftUI.Color {
            SwiftUI.Color("Personality/\(rawValue)")
        }

        /// Get color with specified opacity
        func withOpacity(_ opacity: Double) -> SwiftUI.Color {
            color.opacity(opacity)
        }

        /// Get default color when asset is missing
        static var defaultColor: SwiftUI.Color {
            .gray
        }
    }

    // MARK: - Safe Asset Loading

    /// Get a UIImage by name with proper error handling
    public static func image(name: String) throws -> UIKit.UIImage {
        guard let image = UIKit.UIImage(named: name) else {
            throw AssetError.missingImage(name)
        }
        return image
    }

    /// Get a UIColor by name with proper error handling
    public static func color(name: String) throws -> UIKit.UIColor {
        guard let color = UIKit.UIColor(named: name) else {
            throw AssetError.missingColor(name)
        }
        return color
    }

    // MARK: - Asset Validation

    /// Validate all required assets are available
    public static func validateAssets() -> Bool {
        var isValid = true

        // Validate mood colors
        for mood in MoodColor.allCases {
            if UIKit.UIColor(named: "Mood/\(mood.rawValue)") == nil {
                print("Missing mood color asset: \(mood.rawValue)")
                isValid = false
            }
        }

        // Validate personality colors
        for personality in PersonalityColor.allCases {
            if UIKit.UIColor(named: "Personality/\(personality.rawValue)") == nil {
                print("Missing personality color asset: \(personality.rawValue)")
                isValid = false
            }
        }

        // Validate base colors
        for color in Color.allCases {
            if UIKit.UIColor(named: color.rawValue) == nil {
                print("Missing color asset: \(color.rawValue)")
                isValid = false
            }
        }

        // Validate images
        for image in Image.allCases {
            if UIKit.UIImage(named: image.rawValue) == nil {
                print("Missing image asset: \(image.rawValue)")
                isValid = false
            }
        }

        return isValid
    }
}
