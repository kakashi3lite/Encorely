import SwiftUI

/// Custom environment keys for dependency injection without third-party DI.

// MARK: - MusicKit Service

struct MusicKitServiceKey: EnvironmentKey {
    static let defaultValue: MusicKitService = MusicKitService()
}

extension EnvironmentValues {
    var musicKitService: MusicKitService {
        get { self[MusicKitServiceKey.self] }
        set { self[MusicKitServiceKey.self] = newValue }
    }
}
