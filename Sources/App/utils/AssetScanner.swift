import Foundation

/// Scans the Assets.xcassets directory and catalogs all image sets and color sets.
struct AssetScanner {
    
    enum AssetType: String {
        case imageSet = "imageset"
        case colorSet = "colorset"
        case appIconSet = "appiconset"
        case symbolSet = "symbolset"
        case dataSet = "dataset"
        case unknown
    }
    
    struct AssetInfo: Codable {
        let name: String
        let type: String
        let path: String
        let contents: [String: Any]?
        
        enum CodingKeys: String, CodingKey {
            case name, type, path, contents
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(type, forKey: .type)
            try container.encode(path, forKey: .path)
            
            // Contents cannot be directly encoded, as it's [String: Any]
            // In a real implementation, we would use a proper JSON serialization
        }
        
        init(name: String, type: String, path: String, contents: [String: Any]? = nil) {
            self.name = name
            self.type = type
            self.path = path
            self.contents = contents
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            type = try container.decode(String.self, forKey: .type)
            path = try container.decode(String.self, forKey: .path)
            contents = nil
        }
    }
    
    let assetCatalogPath: String
    
    init(assetCatalogPath: String) {
        self.assetCatalogPath = assetCatalogPath
    }
    
    /// Scans the asset catalog and returns information about all assets
    func scanAssets() -> [AssetInfo] {
        var assets: [AssetInfo] = []
        
        do {
            let fileManager = FileManager.default
            let assetCatalogContents = try fileManager.contentsOfDirectory(atPath: assetCatalogPath)
            
            for item in assetCatalogContents {
                let itemPath = "\(assetCatalogPath)/\(item)"
                var isDirectory: ObjCBool = false
                
                guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory), isDirectory.boolValue else {
                    // Skip regular files like Contents.json at the root
                    continue
                }
                
                // Determine asset type based on extension
                let itemExtension = URL(fileURLWithPath: item).pathExtension
                let assetType = AssetType(rawValue: itemExtension) ?? .unknown
                
                if assetType != .unknown {
                    // This is a valid asset directory
                    let contentsPath = "\(itemPath)/Contents.json"
                    if fileManager.fileExists(atPath: contentsPath) {
                        let contentsData = try Data(contentsOf: URL(fileURLWithPath: contentsPath))
                        let contents = try JSONSerialization.jsonObject(with: contentsData) as? [String: Any]
                        
                        let assetName = URL(fileURLWithPath: item).deletingPathExtension().lastPathComponent
                        let asset = AssetInfo(
                            name: assetName,
                            type: assetType.rawValue,
                            path: itemPath,
                            contents: contents
                        )
                        assets.append(asset)
                    }
                    
                    // For directories that contain nested assets (like Colors directory)
                    if assetType == .unknown {
                        let nestedAssets = try scanNestedDirectory(path: itemPath)
                        assets.append(contentsOf: nestedAssets)
                    }
                }
            }
        } catch {
            print("Error scanning assets: \(error)")
        }
        
        return assets
    }
    
    /// Scans a nested directory for assets
    private func scanNestedDirectory(path: String) throws -> [AssetInfo] {
        var nestedAssets: [AssetInfo] = []
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: path)
        
        for item in contents {
            let itemPath = "\(path)/\(item)"
            var isDirectory: ObjCBool = false
            
            guard fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            
            // Determine asset type based on extension
            let itemExtension = URL(fileURLWithPath: item).pathExtension
            let assetType = AssetType(rawValue: itemExtension) ?? .unknown
            
            if assetType != .unknown {
                // This is a valid asset directory
                let contentsPath = "\(itemPath)/Contents.json"
                if fileManager.fileExists(atPath: contentsPath) {
                    let contentsData = try Data(contentsOf: URL(fileURLWithPath: contentsPath))
                    let contents = try JSONSerialization.jsonObject(with: contentsData) as? [String: Any]
                    
                    let assetName = URL(fileURLWithPath: item).deletingPathExtension().lastPathComponent
                    let directoryName = URL(fileURLWithPath: path).lastPathComponent
                    let fullName = "\(directoryName)/\(assetName)"
                    
                    let asset = AssetInfo(
                        name: fullName,
                        type: assetType.rawValue,
                        path: itemPath,
                        contents: contents
                    )
                    nestedAssets.append(asset)
                }
            }
        }
        
        return nestedAssets
    }
}
