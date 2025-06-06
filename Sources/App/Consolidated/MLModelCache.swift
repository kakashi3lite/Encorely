import CoreML
import Foundation

class MLModelCache {
    private let model: MLModel
    private var cachedInputs: [MLFeatureProvider] = []
    private let maxCacheSize = 10
    
    init(modelAsset: MLConfig.ModelAsset) throws {
        guard let url = modelAsset.url else {
            throw AppError.modelLoadFailed
        }
        
        let config = MLModelConfiguration()
        config.computeUnits = MLConfig.Performance.computeUnits
        config.preferredMetalDevice = MLConfig.Performance.preferredMetalDevice
        config.allowLowPrecisionAccumulationOnGPU = MLConfig.Performance.allowLowPrecisionAccumulationOnGPU
        config.preferredMemoryFootprint = MLConfig.Performance.preferredMemoryFootprint
        
        self.model = try MLModel(contentsOf: url, configuration: config)
        
        // Enable memory mapping for faster loading
        if let modelDescription = try? MLModelDescription(contentsOf: url) {
            try? model.setMemoryMappingEnabled(true, for: modelDescription)
        }
    }
    
    func prediction(from input: MLFeatureProvider) throws -> MLFeatureProvider {
        // Check cache first
        if let cachedPrediction = checkCache(for: input) {
            return cachedPrediction
        }
        
        // Perform prediction
        let prediction = try model.prediction(from: input)
        
        // Cache result
        updateCache(input: input, prediction: prediction)
        
        return prediction
    }
    
    private func checkCache(for input: MLFeatureProvider) -> MLFeatureProvider? {
        // Implement cache lookup logic here
        // This is a simple example - you might want to implement a more sophisticated caching strategy
        return nil
    }
    
    private func updateCache(input: MLFeatureProvider, prediction: MLFeatureProvider) {
        // Add to cache
        if cachedInputs.count >= maxCacheSize {
            cachedInputs.removeFirst()
        }
        cachedInputs.append(input)
    }
}
