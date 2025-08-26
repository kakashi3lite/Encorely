import Foundation
import MusicKit

public class MusicKitService {
    public init() {}
    
    public func requestMusicAuthorization() async -> Bool {
        let status = await MusicAuthorization.request()
        return status == .authorized
    }
    
    public func searchMusic(term: String) async throws -> MusicItemCollection<Song> {
        var searchRequest = MusicCatalogSearchRequest(term: term, types: [Song.self])
        return try await searchRequest.response().songs
    }
    
    #if os(iOS)
    public func fetchRecommendations() async throws -> MusicPersonalRecommendations {
        return try await MusicPersonalRecommendations.get()
    }
    #endif
}
