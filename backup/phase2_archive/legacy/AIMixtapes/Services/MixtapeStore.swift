//
//  MixtapeStore.swift
//  AI Mixtapes
//
//  Created by AI Assistant on 2024
//  Copyright © 2024 AI Mixtapes. All rights reserved.
//

import SwiftUI
import Combine
import CoreData
import MusicKit

/// Manages mixtape data and operations
class MixtapeStore: ObservableObject {
    // MARK: - Published Properties
    @Published var mixtapes: [Mixtape] = []
    @Published var currentMixtape: Mixtape?
    @Published var isGenerating = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let coreDataManager = CoreDataManager.shared
    private let aiEngine = AIEngine.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        loadMixtapes()
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Load all mixtapes from storage
    func loadMixtapes() {
        isLoading = true
        
        Task {
            do {
                let fetchedMixtapes = try await coreDataManager.fetchMixtapes()
                
                await MainActor.run {
                    self.mixtapes = fetchedMixtapes
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load mixtapes: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Generate a new mixtape based on mood and preferences
    @MainActor
    func generateMixtape(for mood: Mood, preferences: MixtapePreferences = MixtapePreferences()) async {
        guard !isGenerating else { return }
        
        isGenerating = true
        errorMessage = nil
        
        do {
            let mixtape = try await aiEngine.generateMixtape(
                mood: mood,
                preferences: preferences
            )
            
            // Save to Core Data
            try await coreDataManager.saveMixtape(mixtape)
            
            // Update local state
            mixtapes.insert(mixtape, at: 0)
            currentMixtape = mixtape
            
        } catch {
            errorMessage = "Failed to generate mixtape: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
    
    /// Delete a mixtape
    func deleteMixtape(_ mixtape: Mixtape) {
        Task {
            do {
                try await coreDataManager.deleteMixtape(mixtape)
                
                await MainActor.run {
                    self.mixtapes.removeAll { $0.id == mixtape.id }
                    
                    if self.currentMixtape?.id == mixtape.id {
                        self.currentMixtape = nil
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to delete mixtape: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Update mixtape metadata
    func updateMixtape(_ mixtape: Mixtape) {
        Task {
            do {
                try await coreDataManager.updateMixtape(mixtape)
                
                await MainActor.run {
                    if let index = self.mixtapes.firstIndex(where: { $0.id == mixtape.id }) {
                        self.mixtapes[index] = mixtape
                    }
                    
                    if self.currentMixtape?.id == mixtape.id {
                        self.currentMixtape = mixtape
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update mixtape: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Set current playing mixtape
    func setCurrentMixtape(_ mixtape: Mixtape?) {
        currentMixtape = mixtape
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Get mixtapes filtered by mood
    func mixtapes(for mood: Mood) -> [Mixtape] {
        return mixtapes.filter { $0.mood == mood }
    }
    
    /// Get recently created mixtapes
    func recentMixtapes(limit: Int = 5) -> [Mixtape] {
        return Array(mixtapes.prefix(limit))
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Monitor Core Data changes
        NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                self?.loadMixtapes()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Types

struct Mixtape: Identifiable, Codable {
    let id: UUID
    var name: String
    var mood: Mood
    var songs: [Song]
    var duration: TimeInterval
    var createdAt: Date
    var lastPlayedAt: Date?
    var playCount: Int
    var isFavorite: Bool
    var artwork: Data?
    
    init(
        name: String,
        mood: Mood,
        songs: [Song] = []
    ) {
        self.id = UUID()
        self.name = name
        self.mood = mood
        self.songs = songs
        self.duration = songs.reduce(0) { $0 + $1.duration }
        self.createdAt = Date()
        self.lastPlayedAt = nil
        self.playCount = 0
        self.isFavorite = false
        self.artwork = nil
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var songCount: Int {
        return songs.count
    }
}

struct Song: Identifiable, Codable {
    let id: String // MusicKit song ID
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval
    let artworkURL: URL?
    let previewURL: URL?
    let isExplicit: Bool
    
    init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        duration: TimeInterval,
        artworkURL: URL? = nil,
        previewURL: URL? = nil,
        isExplicit: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
        self.previewURL = previewURL
        self.isExplicit = isExplicit
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

enum Mood: String, CaseIterable, Codable {
    case energetic = "energetic"
    case calm = "calm"
    case happy = "happy"
    case melancholic = "melancholic"
    case focused = "focused"
    case romantic = "romantic"
    case nostalgic = "nostalgic"
    case adventurous = "adventurous"
    case neutral = "neutral"
    
    var displayName: String {
        switch self {
        case .energetic:
            return "Energetic"
        case .calm:
            return "Calm"
        case .happy:
            return "Happy"
        case .melancholic:
            return "Melancholic"
        case .focused:
            return "Focused"
        case .romantic:
            return "Romantic"
        case .nostalgic:
            return "Nostalgic"
        case .adventurous:
            return "Adventurous"
        case .neutral:
            return "Neutral"
        }
    }
    
    var emoji: String {
        switch self {
        case .energetic:
            return "⚡️"
        case .calm:
            return "🧘‍♀️"
        case .happy:
            return "😊"
        case .melancholic:
            return "😔"
        case .focused:
            return "🎯"
        case .romantic:
            return "💕"
        case .nostalgic:
            return "📸"
        case .adventurous:
            return "🗺️"
        case .neutral:
            return "😐"
        }
    }
    
    var color: Color {
        switch self {
        case .energetic:
            return .orange
        case .calm:
            return .blue
        case .happy:
            return .yellow
        case .melancholic:
            return .purple
        case .focused:
            return .green
        case .romantic:
            return .pink
        case .nostalgic:
            return .brown
        case .adventurous:
            return .red
        case .neutral:
            return .gray
        }
    }
}

struct MixtapePreferences: Codable {
    var duration: TimeInterval = 3600 // 1 hour default
    var genres: [String] = []
    var excludeExplicit: Bool = false
    var includePopular: Bool = true
    var includeDiscovery: Bool = true
    var energyLevel: Double = 0.5 // 0.0 to 1.0
    var danceability: Double = 0.5 // 0.0 to 1.0
    var valence: Double = 0.5 // 0.0 to 1.0 (positivity)
    
    init() {}
}

// MARK: - Preview Support
#if DEBUG
extension MixtapeStore {
    static var preview: MixtapeStore {
        let store = MixtapeStore()
        store.mixtapes = [
            Mixtape(name: "Morning Energy", mood: .energetic),
            Mixtape(name: "Chill Vibes", mood: .calm),
            Mixtape(name: "Happy Times", mood: .happy)
        ]
        return store
    }
}

extension Mixtape {
    static var preview: Mixtape {
        return Mixtape(
            name: "Sample Mixtape",
            mood: .energetic,
            songs: [
                Song(
                    id: "1",
                    title: "Sample Song",
                    artist: "Sample Artist",
                    album: "Sample Album",
                    duration: 180
                )
            ]
        )
    }
}
#endif