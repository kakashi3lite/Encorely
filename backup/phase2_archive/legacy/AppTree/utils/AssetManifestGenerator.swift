import Foundation

/// Generates an asset manifest JSON file from the scanned asset catalog
struct AssetManifestGenerator {
    struct Manifest: Codable {
        let generatedAt: String
        let assets: [Asset]

        struct Asset: Codable {
            let name: String
            let type: String
            let path: String
            let requiredForApp: Bool
        }
    }

    let assetScanner: AssetScanner
    let requiredAssets: [String]

    init(assetScanner: AssetScanner, requiredAssets: [String] = []) {
        self.assetScanner = assetScanner
        self.requiredAssets = requiredAssets
    }

    /// Generate the manifest and save to the specified file path
    func generateManifest(outputPath: String) {
        let assets = assetScanner.scanAssets()

        // Format date for manifest
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())

        // Create manifest structure
        let manifestAssets = assets.map { asset -> Manifest.Asset in
            return Manifest.Asset(
                name: asset.name,
                type: asset.type,
                path: asset.path,
                requiredForApp: requiredAssets.contains(asset.name)
            )
        }

        let manifest = Manifest(
            generatedAt: timestamp,
            assets: manifestAssets
        )

        // Serialize to JSON
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(manifest)

            // Write to file
            try data.write(to: URL(fileURLWithPath: outputPath))
            print("Asset manifest generated successfully at \(outputPath)")
        } catch {
            print("Error generating asset manifest: \(error)")
        }
    }
}
