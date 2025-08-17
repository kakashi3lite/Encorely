import Foundation

// MARK: - Configuration Constants

let ASSETS_PATH = "./Assets.xcassets"
let MANIFEST_PATH = "./ASSET_MANIFEST.json"
let REQUIRED_ASSETS = [
    "AppIcon",
    "LaunchIcon",
    "Colors/appPrimary",
    "Colors/appSecondary",
    "Colors/background",
]

// MARK: - Asset Pipeline

/// Main class for running the asset pipeline
class AssetPipeline {
    let assetCatalogPath: String
    let manifestPath: String
    let requiredAssets: [String]

    init(assetCatalogPath: String, manifestPath: String, requiredAssets: [String]) {
        self.assetCatalogPath = assetCatalogPath
        self.manifestPath = manifestPath
        self.requiredAssets = requiredAssets
    }

    /// Run the entire asset pipeline
    func run() -> Bool {
        print("🔍 Step 1: Scanning asset catalog...")
        let scanner = AssetScanner(assetCatalogPath: assetCatalogPath)
        let assets = scanner.scanAssets()

        print("📝 Found \(assets.count) assets in the catalog")

        print("\n📊 Step 2: Generating asset manifest...")
        let generator = AssetManifestGenerator(assetScanner: scanner, requiredAssets: requiredAssets)
        generator.generateManifest(outputPath: manifestPath)

        print("\n✅ Step 3: Validating assets against manifest...")
        let validator = AssetValidator(manifestPath: manifestPath, assetCatalogPath: assetCatalogPath)
        let result = validator.validateAssets()

        if result.isValid {
            print("✅ All required assets are valid!")
        } else {
            if !result.missingAssets.isEmpty {
                print("❌ Missing required assets:")
                for asset in result.missingAssets {
                    print("  - \(asset)")
                }
            }

            if !result.invalidAssets.isEmpty {
                print("❌ Invalid assets:")
                for asset in result.invalidAssets {
                    print("  - \(asset)")
                }
            }

            if !result.extraAssets.isEmpty {
                print("ℹ️ Extra assets not in manifest:")
                for asset in result.extraAssets {
                    print("  - \(asset)")
                }
            }
        }

        return result.isValid
    }
}

// MARK: - Entry Point

// When run as a script
if CommandLine.arguments[0].contains("AssetPipelineRunner") {
    print("📦 Running Asset Pipeline...")
    let pipeline = AssetPipeline(
        assetCatalogPath: ASSETS_PATH,
        manifestPath: MANIFEST_PATH,
        requiredAssets: REQUIRED_ASSETS
    )

    let success = pipeline.run()
    exit(success ? 0 : 1)
}
