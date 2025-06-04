import Foundation
import UIKit

/// Validates assets against the manifest
struct AssetValidator {
    
    struct ValidationResult {
        let isValid: Bool
        let missingAssets: [String]
        let extraAssets: [String]
        let invalidAssets: [String]
    }
    
    let manifestPath: String
    let assetCatalogPath: String
    
    init(manifestPath: String, assetCatalogPath: String) {
        self.manifestPath = manifestPath
        self.assetCatalogPath = assetCatalogPath
    }
    
    /// Validate assets against the manifest
    func validateAssets() -> ValidationResult {
        var missingAssets: [String] = []
        var extraAssets: [String] = []
        var invalidAssets: [String] = []
        
        // Load manifest
        guard let manifestData = try? Data(contentsOf: URL(fileURLWithPath: manifestPath)),
              let manifest = try? JSONDecoder().decode(AssetManifestGenerator.Manifest.self, from: manifestData) else {
            print("Failed to load or parse manifest")
            return ValidationResult(isValid: false, missingAssets: [], extraAssets: [], invalidAssets: ["Invalid manifest"])
        }
        
        // Scan current assets
        let scanner = AssetScanner(assetCatalogPath: assetCatalogPath)
        let currentAssets = scanner.scanAssets()
        
        // Extract names from current assets
        let currentAssetNames = Set(currentAssets.map { $0.name })
        
        // Extract names from manifest
        let manifestAssetNames = Set(manifest.assets.map { $0.name })
        
        // Find missing and extra assets
        let requiredManifestAssets = manifest.assets.filter { $0.requiredForApp }
        let requiredAssetNames = Set(requiredManifestAssets.map { $0.name })
        
        missingAssets = requiredAssetNames.subtracting(currentAssetNames).sorted()
        extraAssets = currentAssetNames.subtracting(manifestAssetNames).sorted()
        
        // Validate asset types
        for currentAsset in currentAssets {
            if let manifestAsset = manifest.assets.first(where: { $0.name == currentAsset.name }) {
                if currentAsset.type != manifestAsset.type {
                    invalidAssets.append("\(currentAsset.name) (expected: \(manifestAsset.type), found: \(currentAsset.type))")
                }
            }
        }
        
        return ValidationResult(
            isValid: missingAssets.isEmpty && invalidAssets.isEmpty,
            missingAssets: missingAssets,
            extraAssets: extraAssets,
            invalidAssets: invalidAssets
        )
    }
    
    static func validateAllAssets() -> Bool {
        var isValid = true
        
        // Validate mood colors
        for mood in Asset.MoodColor.allCases {
            if !validateMoodColor(mood) {
                print("❌ Missing mood color asset: \(mood.rawValue)")
                isValid = false
            }
        }
        
        // Validate personality colors
        for personality in Asset.PersonalityColor.allCases {
            if !validatePersonalityColor(personality) {
                print("❌ Missing personality color asset: \(personality.rawValue)")
                isValid = false
            }
        }
        
        // Validate base colors
        let baseColors: [Asset.Color] = [.appPrimary, .appSecondary, .background]
        for color in baseColors {
            if !validateBaseColor(color) {
                print("❌ Missing base color asset: \(color.rawValue)")
                isValid = false
            }
        }
        
        // Validate images
        if !validateImage(.launchIcon) {
            print("❌ Missing launch icon asset")
            isValid = false
        }
        
        return isValid
    }
    
    private static func validateMoodColor(_ mood: Asset.MoodColor) -> Bool {
        guard let _ = UIColor(named: "Mood/\(mood.rawValue)") else {
            return false
        }
        return true
    }
    
    private static func validatePersonalityColor(_ personality: Asset.PersonalityColor) -> Bool {
        guard let _ = UIColor(named: "Personality/\(personality.rawValue)") else {
            return false
        }
        return true
    }
    
    private static func validateBaseColor(_ color: Asset.Color) -> Bool {
        guard let _ = UIColor(named: color.rawValue) else {
            return false
        }
        return true
    }
    
    private static func validateImage(_ image: Asset.Image) -> Bool {
        guard let _ = UIImage(named: image.rawValue) else {
            return false
        }
        return true
    }
    
    static func validateColorAssets() {
        print("🔍 Validating color assets...")
        
        // Validate mood colors
        print("\n📊 Mood Colors:")
        for mood in Asset.MoodColor.allCases {
            let status = validateMoodColor(mood) ? "✅" : "❌"
            print("\(status) \(mood.rawValue)")
        }
        
        // Validate personality colors
        print("\n👤 Personality Colors:")
        for personality in Asset.PersonalityColor.allCases {
            let status = validatePersonalityColor(personality) ? "✅" : "❌"
            print("\(status) \(personality.rawValue)")
        }
        
        // Validate base colors
        print("\n🎨 Base Colors:")
        let baseColors: [Asset.Color] = [.appPrimary, .appSecondary, .background]
        for color in baseColors {
            let status = validateBaseColor(color) ? "✅" : "❌"
            print("\(status) \(color.rawValue)")
        }
    }
}
