import Foundation
@testable import AIMixtapes

class NetworkStateManager {
    static let shared = NetworkStateManager()
    
    private(set) var isOffline = false
    private var networkErrors: [String: Error] = [:]
    
    func setOfflineMode(_ offline: Bool) {
        isOffline = offline
    }
    
    func simulateNetworkError(for operation: String, error: Error) {
        networkErrors[operation] = error
    }
    
    func clearNetworkErrors() {
        networkErrors.removeAll()
    }
    
    func getError(for operation: String) -> Error? {
        return networkErrors[operation]
    }
    
    func reset() {
        isOffline = false
        networkErrors.removeAll()
    }
}
