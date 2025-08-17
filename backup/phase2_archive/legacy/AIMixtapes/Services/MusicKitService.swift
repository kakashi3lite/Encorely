import Foundation
import MusicKit

/// Service for handling all MusicKit-related functionality
final class MusicKitService: ObservableObject {
    static let shared = MusicKitService()

    // Published properties to observe authorization state
    @Published private(set) var authorizationStatus: MusicAuthorization.Status = .notDetermined
    @Published private(set) var isAuthorized = false

    private init() {
        Task {
            await updateAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    /// Request MusicKit authorization from the user
    func requestAuthorization() async -> Bool {
        let status = await MusicAuthorization.request()
        await updateAuthorizationStatus()
        return status == .authorized
    }

    /// Update the current authorization status
    @MainActor
    func updateAuthorizationStatus() async {
        let status = MusicAuthorization.currentStatus
        authorizationStatus = status
        isAuthorized = status == .authorized
    }

    // MARK: - Library Access

    /// Request access to the user's music library
    func requestLibraryAccess() async throws {
        guard await MusicAuthorization.currentStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }

        // Request full library authorization
        try await MusicLibrary.shared.requestAuthorizationIfNeeded(for: [.library])
    }

    /// Get the user's playlists
    func getUserPlaylists() async throws -> [Playlist] {
        guard await MusicAuthorization.currentStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }

        let request = MusicLibrary.PlaylistsRequest()
        let response = try await request.response()
        return response.items
    }

    /// Get recent played items from the user's library
    func getRecentlyPlayed() async throws -> [Song] {
        guard await MusicAuthorization.currentStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }

        let request = MusicLibrary.RecentlyPlayedRequest()
        let response = try await request.response()
        return response.items.compactMap { item in
            if case let .song(song) = item { return song }
            return nil
        }
    }

    // MARK: - Playlist Management

    /// Create a new playlist in the user's library
    func createPlaylist(name: String, description: String? = nil, songs: [Song] = []) async throws -> Playlist {
        guard await MusicAuthorization.currentStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }

        let creationRequest = MusicLibrary.PlaylistCreationRequest(
            name: name,
            description: description,
            items: songs.map { .song($0) }
        )

        return try await creationRequest.response()
    }

    /// Add songs to an existing playlist
    func addToPlaylist(_ playlist: Playlist, songs: [Song]) async throws {
        guard await MusicAuthorization.currentStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }

        let items = songs.map { MusicPlayer.Queue.Item(song: $0) }
        try await playlist.addItems(items)
    }

    // MARK: - Search

    /// Search for songs in Apple Music catalog
    func searchSongs(query: String) async throws -> [Song] {
        guard await MusicAuthorization.currentStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }

        var searchRequest = MusicCatalogSearchRequest(term: query, types: [Song.self])
        searchRequest.limit = 25

        let response = try await searchRequest.response()
        return response.songs
    }
}

// MARK: - Errors

enum MusicKitError: LocalizedError {
    case notAuthorized
    case libraryAccessDenied
    case playlistCreationFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            "Music access not authorized. Please grant access in Settings."
        case .libraryAccessDenied:
            "Access to music library denied. Please grant access in Settings."
        case .playlistCreationFailed:
            "Failed to create playlist. Please try again."
        case .unknown:
            "An unknown error occurred. Please try again."
        }
    }
}
