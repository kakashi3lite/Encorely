import SwiftUI
import UIKit

/// Errors that can occur when loading assets.
///
/// These errors provide specific information about missing resources
/// and proper error handling in both debug and release builds.
///
/// ## Topics
///
/// ### Error Cases
/// - ``missingImage(_:)``
/// - ``missingColor(_:)``
public enum AssetError: LocalizedError {
    case missingImage(String)
    case missingColor(String)

    var errorDescription: String? {
        switch self {
        case let .missingImage(name):
            "Missing image asset: \(name)"
        case let .missingColor(name):
            "Missing color asset: \(name)"
        }
    }
}

/// Asset management system for the AIMixtapes framework.
///
/// The `Asset` enum provides type-safe access to app resources including:
/// - Images
/// - Colors
/// - Mood-based color schemes
/// - Personality-based color schemes
///
/// ## Overview
///
/// The asset system ensures compile-time safety for resource access and provides
/// proper error handling for missing assets in both debug and release builds.
///
/// ### Using Images
/// ```swift
/// // Get a UIImage
/// let image = Asset.Image.launchIcon.uiImage
///
/// // Get a SwiftUI Image
/// let swiftUIImage = Asset.Image.launchIcon.image
/// ```
///
/// ### Using Colors
/// ```swift
/// // Get a UIColor
/// let color = Asset.Color.appPrimary.uiColor
///
/// // Get a SwiftUI Color
/// let swiftUIColor = Asset.Color.appPrimary.color
/// ```
///
/// ### Using Mood Colors
/// ```swift
/// let happyColor = Asset.MoodColor.happy.color
/// let energeticWithOpacity = Asset.MoodColor.energetic.withOpacity(0.5)
/// ```
///
/// ## Topics
///
/// ### Image Assets
/// - ``Image``
///
/// ### Color Assets
/// - ``Color``
/// - ``MoodColor``
/// - ``PersonalityColor``
///
/// ### Error Handling
/// - ``AssetError``
public enum Asset {
    /// Typed access to app image assets.
    ///
    /// Provides compile-time validation of image names and
    /// convenient conversion between UIImage and SwiftUI.Image.
    ///
    /// ## Example
    /// ```swift
    /// let launchIcon = Asset.Image.launchIcon.uiImage
    /// let swiftUIIcon = Asset.Image.launchIcon.image
    /// ```
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

    /// Type-safe access to app color assets.
    ///
    /// Provides compile-time validation of color names and
    /// convenient conversion between UIColor and SwiftUI.Color.
    ///
    /// ## Example
    /// ```swift
    /// let primary = Asset.Color.appPrimary.uiColor
    /// let background = Asset.Color.background.color
    /// ```
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

    /// Mood-based color schemes.
    ///
    /// Provides color assets that represent different moods,
    /// with support for both UIKit and SwiftUI.
    ///
    /// ## Example
    /// ```swift
    /// let happyColor = Asset.MoodColor.happy.color
    /// let energeticFaded = Asset.MoodColor.energetic.withOpacity(0.5)
    /// ```
    ///
    /// ## Topics
    ///
    /// ### Available Moods
    /// - ``angry``
    /// - ``energetic``
    /// - ``focused``
    /// - ``happy``
    /// - ``melancholic``
    /// - ``relaxed``
    public enum MoodColor: String, CaseIterable {
        case angry = "Angry"
        case energetic = "Energetic"
        case focused = "Focused"
        case happy = "Happy"
        case melancholic = "Melancholic"
        case relaxed = "Relaxed"

        /// Get a UIColor for this mood
        var uiColor: UIKit.UIColor {
            guard let color = UIKit.UIColor(named: "Mood/\(rawValue)") else {
                assertionFailure("Missing mood color asset: \(rawValue)")
                return .clear // Return clear color in release builds
            }
            return color
        }

        /// Get a SwiftUI Color for this mood
        var color: SwiftUI.Color {
            SwiftUI.Color("Mood/\(rawValue)")
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

    /// Personality-based color schemes.
    ///
    /// Provides color assets that represent different personality types,
    /// with support for both UIKit and SwiftUI.
    ///
    /// ## Example
    /// ```swift
    /// let curatorColor = Asset.PersonalityColor.curator.color
    /// let explorerFaded = Asset.PersonalityColor.explorer.withOpacity(0.5)
    /// ```
    ///
    /// ## Topics
    ///
    /// ### Available Personalities
    /// - ``curator``
    /// - ``enthusiast``
    /// - ``explorer``
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
    static func image(name: String) throws -> UIKit.UIImage {
        guard let image = UIKit.UIImage(named: name) else {
            throw AssetError.missingImage(name)
        }
        return image
    }

    /// Get a UIColor by name with proper error handling
    static func color(name: String) throws -> UIKit.UIColor {
        guard let color = UIKit.UIColor(named: name) else {
            throw AssetError.missingColor(name)
        }
        return color
    }

    // MARK: - Asset Validation

    /// Validate all required assets are available
    static func validateAssets() -> Bool {
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
