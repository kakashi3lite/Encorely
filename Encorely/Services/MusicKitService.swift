import Foundation
import MusicKit
import Observation
import os.log

/// Wraps Apple's MusicKit framework for authorization, search, and library access.
@Observable
final class MusicKitService: @unchecked Sendable {
    // MARK: - Observable State

    /// Current authorization status.
    private(set) var authorizationStatus: MusicAuthorization.Status = .notDetermined

    /// Whether the user has an active Apple Music subscription.
    private(set) var hasSubscription: Bool = false

    /// Whether a request is in flight.
    private(set) var isLoading: Bool = false

    // MARK: - Private

    private let logger = Logger(subsystem: "com.encorely", category: "MusicKit")

    // MARK: - Authorization

    /// Requests MusicKit authorization. Call on first launch or when user taps "Connect Apple Music".
    @MainActor
    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        authorizationStatus = status
        logger.info("MusicKit auth status: \(String(describing: status))")

        if status == .authorized {
            await checkSubscription()
        }
    }

    /// Checks whether the user's Apple Music subscription is active.
    @MainActor
    func checkSubscription() async {
        do {
            let subscription = try await MusicSubscription.current
            hasSubscription = subscription.canPlayCatalogContent
        } catch {
            logger.error("Subscription check failed: \(error.localizedDescription)")
            hasSubscription = false
        }
    }

    // MARK: - Search

    /// Searches the Apple Music catalog for songs matching a query.
    func searchSongs(query: String, limit: Int = 25) async throws -> [MusicKit.Song] {
        guard authorizationStatus == .authorized else {
            throw MusicKitServiceError.notAuthorized
        }

        isLoading = true
        defer { isLoading = false }

        var request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Song.self])
        request.limit = limit

        let response = try await request.response()
        return Array(response.songs)
    }

    /// Searches songs matching a specific mood using mood keywords.
    func searchByMood(_ mood: Mood, limit: Int = 25) async throws -> [MusicKit.Song] {
        let keyword = mood.keywords.randomElement() ?? mood.rawValue
        let query = "\(keyword) music"
        return try await searchSongs(query: query, limit: limit)
    }

    // MARK: - Library

    /// Fetches the user's library songs.
    func fetchLibrarySongs(limit: Int = 100) async throws -> [MusicKit.Song] {
        guard authorizationStatus == .authorized else {
            throw MusicKitServiceError.notAuthorized
        }

        isLoading = true
        defer { isLoading = false }

        var request = MusicLibraryRequest<MusicKit.Song>()
        request.limit = limit

        let response = try await request.response()
        return Array(response.items)
    }

    // MARK: - Playlist Creation

    /// Creates a new playlist in the user's Apple Music library.
    func createPlaylist(name: String, description: String, songs: [MusicKit.Song]) async throws {
        guard authorizationStatus == .authorized else {
            throw MusicKitServiceError.notAuthorized
        }

        isLoading = true
        defer { isLoading = false }

        let library = MusicLibrary.shared
        let playlist = try await library.createPlaylist(name: name, description: description, items: songs)
        logger.info("Created playlist: \(playlist.name)")
    }
}

// MARK: - Errors

enum MusicKitServiceError: LocalizedError {
    case notAuthorized
    case noSubscription
    case searchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:       "Apple Music access not authorized."
        case .noSubscription:      "An Apple Music subscription is required."
        case .searchFailed(let e): "Search failed: \(e.localizedDescription)"
        }
    }
}
