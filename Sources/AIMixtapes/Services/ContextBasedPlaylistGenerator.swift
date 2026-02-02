//
//  ContextBasedPlaylistGenerator.swift
//  Mixtapes
//
//  Created by Claude AI on 05/18/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation

// MARK: - Playlist Models

struct Playlist {
    let id: UUID
    let name: String
    let songs: [Song]
    let mood: Mood
    let generatedDate: Date
    let context: PlaylistContext
    let moodProgression: MoodProgression?
}

struct PlaylistContext {
    let mood: Mood
    let timeOfDay: TimeOfDay
    let activityType: ActivityType?
    let duration: TimeInterval?
    let energyProgression: EnergyProgression
}

enum TimeOfDay: String, CaseIterable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"
    
    var moodBias: [Mood: Float] {
        switch self {
        case .morning:
            return [.energetic: 0.8, .happy: 0.7, .focused: 0.9]
        case .afternoon:
            return [.focused: 0.9, .energetic: 0.6, .neutral: 0.8]
        case .evening:
            return [.relaxed: 0.9, .romantic: 0.8, .happy: 0.7]
        case .night:
            return [.relaxed: 0.9, .melancholic: 0.6, .neutral: 0.8]
        }
    }
}

enum ActivityType: String, CaseIterable {
    case workout = "workout"
    case study = "study"
    case commute = "commute"
    case party = "party"
    case sleep = "sleep"
    case work = "work"
    case relaxation = "relaxation"
    
    var preferredMoods: [Mood] {
        switch self {
        case .workout: return [.energetic, .angry]
        case .study: return [.focused, .neutral]
        case .commute: return [.energetic, .happy, .focused]
        case .party: return [.happy, .energetic]
        case .sleep: return [.relaxed, .melancholic]
        case .work: return [.focused, .neutral]
        case .relaxation: return [.relaxed, .romantic]
        }
    }
}

enum EnergyProgression: String, CaseIterable {
    case ascending = "ascending"     // Low to high energy
    case descending = "descending"   // High to low energy
    case steady = "steady"           // Maintain energy level
    case wave = "wave"               // Energy fluctuations
}

enum MoodProgression: String, CaseIterable {
    case gradual = "gradual"         // Smooth mood transition
    case plateau = "plateau"         // Maintain mood
    case contrast = "contrast"       // Mix different moods
}

// MARK: - Context-Based Playlist Generator

class ContextBasedPlaylistGenerator {
    private let audioAnalysisService: AudioAnalysisService
    private let moodEngine: MoodEngine
    
    init(audioAnalysisService: AudioAnalysisService, moodEngine: MoodEngine) {
        self.audioAnalysisService = audioAnalysisService
        self.moodEngine = moodEngine
    }
    
    /// Generate a context-aware playlist from available songs
    func generatePlaylist(
        from songs: [Song],
        context: PlaylistContext,
        maxSongs: Int = 20
    ) -> Playlist {
        
        // Step 1: Filter songs based on mood compatibility
        let compatibleSongs = filterSongsByMoodCompatibility(
            songs: songs,
            targetMood: context.mood,
            timeOfDay: context.timeOfDay,
            activityType: context.activityType
        )
        
        // Step 2: Sort songs by audio features to create progression
        let sortedSongs = sortSongsForProgression(
            songs: compatibleSongs,
            context: context
        )
        
        // Step 3: Select optimal subset based on duration constraints
        let selectedSongs = selectOptimalSongs(
            from: sortedSongs,
            maxSongs: maxSongs,
            targetDuration: context.duration
        )
        
        // Step 4: Create playlist with metadata
        return Playlist(
            id: UUID(),
            name: generatePlaylistName(context: context),
            songs: selectedSongs,
            mood: context.mood,
            generatedDate: Date(),
            context: context,
            moodProgression: determineMoodProgression(context: context)
        )
    }
    
    // MARK: - Song Filtering
    
    private func filterSongsByMoodCompatibility(
        songs: [Song],
        targetMood: Mood,
        timeOfDay: TimeOfDay,
        activityType: ActivityType?
    ) -> [Song] {
        
        return songs.compactMap { song in
            guard let features = song.getAudioFeatures() else { return nil }
            
            let moodScore = calculateMoodCompatibilityScore(
                features: features,
                targetMood: targetMood,
                timeOfDay: timeOfDay
            )
            
            let activityScore = calculateActivityCompatibilityScore(
                features: features,
                activityType: activityType
            )
            
            let combinedScore = (moodScore * 0.7) + (activityScore * 0.3)
            
            // Only include songs with compatibility score > 0.3
            return combinedScore > 0.3 ? song : nil
        }
    }
    
    private func calculateMoodCompatibilityScore(
        features: AudioFeatures,
        targetMood: Mood,
        timeOfDay: TimeOfDay
    ) -> Float {
        var score: Float = 0.0
        
        switch targetMood {
        case .energetic:
            score = (features.energy * 0.4) + 
                   (features.danceability * 0.3) + 
                   (min(features.tempo / 140.0, 1.0) * 0.2) +
                   (features.liveness * 0.1)
            
        case .relaxed:
            score = ((1.0 - features.energy) * 0.3) + 
                   (features.acousticness * 0.3) + 
                   ((1.0 - features.tempo / 140.0) * 0.2) +
                   ((1.0 - features.danceability) * 0.2)
            
        case .happy:
            score = (features.valence * 0.4) + 
                   (features.danceability * 0.3) + 
                   (features.energy * 0.2) +
                   ((1.0 - features.speechiness) * 0.1)
            
        case .melancholic:
            score = ((1.0 - features.valence) * 0.4) + 
                   (features.acousticness * 0.2) + 
                   ((1.0 - features.danceability) * 0.2) +
                   ((1.0 - features.energy) * 0.2)
            
        case .focused:
            score = (features.instrumentalness * 0.4) + 
                   ((1.0 - features.speechiness) * 0.3) + 
                   (calculateEnergyBalance(features.energy) * 0.2) +
                   ((1.0 - features.liveness) * 0.1)
            
        case .romantic:
            score = (features.valence * 0.3) + 
                   (features.acousticness * 0.3) + 
                   ((1.0 - features.energy) * 0.2) +
                   ((1.0 - features.instrumentalness) * 0.2)
            
        case .angry:
            score = (features.energy * 0.4) + 
                   ((1.0 - features.valence) * 0.3) + 
                   (min(features.tempo / 150.0, 1.0) * 0.2) +
                   ((1.0 - features.acousticness) * 0.1)
            
        case .neutral:
            score = 0.5 + 
                   ((1.0 - abs(features.valence - 0.5)) * 0.3) +
                   ((1.0 - abs(features.energy - 0.5)) * 0.3) +
                   ((1.0 - abs(features.danceability - 0.5)) * 0.2) +
                   ((1.0 - abs(features.acousticness - 0.5)) * 0.2)
        }
        
        // Apply time-of-day bias
        if let timeBias = timeOfDay.moodBias[targetMood] {
            score *= timeBias
        }
        
        return min(max(score, 0.0), 1.0)
    }
    
    private func calculateActivityCompatibilityScore(
        features: AudioFeatures,
        activityType: ActivityType?
    ) -> Float {
        guard let activity = activityType else { return 0.5 }
        
        switch activity {
        case .workout:
            return (features.energy * 0.4) + 
                   (features.danceability * 0.3) + 
                   (min(features.tempo / 140.0, 1.0) * 0.2) +
                   (features.liveness * 0.1)
            
        case .study:
            return (features.instrumentalness * 0.4) + 
                   ((1.0 - features.speechiness) * 0.4) + 
                   (calculateEnergyBalance(features.energy) * 0.2)
            
        case .commute:
            return (features.valence * 0.3) + 
                   (features.energy * 0.3) + 
                   (features.danceability * 0.2) +
                   (features.liveness * 0.2)
            
        case .party:
            return (features.danceability * 0.4) + 
                   (features.energy * 0.3) + 
                   (features.liveness * 0.2) +
                   (features.valence * 0.1)
            
        case .sleep:
            return ((1.0 - features.energy) * 0.4) + 
                   (features.acousticness * 0.3) + 
                   ((1.0 - features.tempo / 100.0) * 0.2) +
                   ((1.0 - features.speechiness) * 0.1)
            
        case .work:
            return (features.instrumentalness * 0.4) + 
                   ((1.0 - features.speechiness) * 0.3) + 
                   (calculateEnergyBalance(features.energy) * 0.2) +
                   ((1.0 - features.liveness) * 0.1)
            
        case .relaxation:
            return ((1.0 - features.energy) * 0.3) + 
                   (features.acousticness * 0.3) + 
                   ((1.0 - features.tempo / 120.0) * 0.2) +
                   (features.valence * 0.2)
        }
    }
    
    private func calculateEnergyBalance(_ energy: Float) -> Float {
        // Prefer moderate energy levels (around 0.4-0.6) for focused activities
        let optimal: Float = 0.5
        let distance = abs(energy - optimal)
        return 1.0 - (distance * 2.0)
    }
    
    // MARK: - Song Sorting
    
    private func sortSongsForProgression(
        songs: [Song],
        context: PlaylistContext
    ) -> [Song] {
        
        switch context.energyProgression {
        case .ascending:
            return sortSongsAscending(songs)
        case .descending:
            return sortSongsDescending(songs)
        case .steady:
            return sortSongsSteady(songs, targetMood: context.mood)
        case .wave:
            return sortSongsWave(songs)
        }
    }
    
    private func sortSongsAscending(_ songs: [Song]) -> [Song] {
        // Optimize: Pre-calculate energy for all songs to avoid repeated computation during sort
        let songsWithEnergy = songs.compactMap { song -> (song: Song, energy: Float)? in
            guard let features = song.getAudioFeatures() else { return nil }
            let energy = (features.energy + features.danceability) / 2
            return (song, energy)
        }
        
        return songsWithEnergy
            .sorted { $0.energy < $1.energy }
            .map { $0.song }
    }
    
    private func sortSongsDescending(_ songs: [Song]) -> [Song] {
        // Optimize: Pre-calculate energy for all songs to avoid repeated computation during sort
        let songsWithEnergy = songs.compactMap { song -> (song: Song, energy: Float)? in
            guard let features = song.getAudioFeatures() else { return nil }
            let energy = (features.energy + features.danceability) / 2
            return (song, energy)
        }
        
        return songsWithEnergy
            .sorted { $0.energy > $1.energy }
            .map { $0.song }
    }
    
    private func sortSongsSteady(_ songs: [Song], targetMood: Mood) -> [Song] {
        // Optimize: Pre-calculate scores for all songs to avoid repeated computation during sort
        let songsWithScores = songs.compactMap { song -> (song: Song, score: Float)? in
            guard let features = song.getAudioFeatures() else { return nil }
            let score = calculateMoodCompatibilityScore(
                features: features,
                targetMood: targetMood,
                timeOfDay: .afternoon // Default for steady sorting
            )
            return (song, score)
        }
        
        return songsWithScores
            .sorted { $0.score > $1.score }
            .map { $0.song }
    }
    
    private func sortSongsWave(_ songs: [Song]) -> [Song] {
        let sorted = sortSongsAscending(songs)
        var result: [Song] = []
        
        // Create wave pattern: low-high-low-high
        for i in stride(from: 0, to: sorted.count, by: 4) {
            if i < sorted.count { result.append(sorted[i]) }           // Low
            if i + 2 < sorted.count { result.append(sorted[i + 2]) }   // Medium-high
            if i + 1 < sorted.count { result.append(sorted[i + 1]) }   // Medium-low
            if i + 3 < sorted.count { result.append(sorted[i + 3]) }   // High
        }
        
        return result
    }
    
    // MARK: - Song Selection
    
    private func selectOptimalSongs(
        from songs: [Song],
        maxSongs: Int,
        targetDuration: TimeInterval?
    ) -> [Song] {
        
        guard let duration = targetDuration else {
            return Array(songs.prefix(maxSongs))
        }
        
        var selectedSongs: [Song] = []
        var totalDuration: TimeInterval = 0
        
        for song in songs {
            let estimatedDuration: TimeInterval = 240 // 4 minutes default
            
            if totalDuration + estimatedDuration <= duration && selectedSongs.count < maxSongs {
                selectedSongs.append(song)
                totalDuration += estimatedDuration
            }
        }
        
        return selectedSongs
    }
    
    // MARK: - Playlist Naming
    
    private func generatePlaylistName(context: PlaylistContext) -> String {
        let timePrefix = getTimePrefix(context.timeOfDay)
        let activitySuffix = getActivitySuffix(context.activityType)
        
        let baseName: String
        switch context.mood {
        case .energetic:
            baseName = "Energy Boost"
        case .relaxed:
            baseName = "Chill Session"
        case .happy:
            baseName = "Good Vibes"
        case .melancholic:
            baseName = "Reflection"
        case .focused:
            baseName = "Focus Zone"
        case .romantic:
            baseName = "Love Songs"
        case .angry:
            baseName = "Intensity"
        case .neutral:
            baseName = "Mix"
        }
        
        if let suffix = activitySuffix {
            return "\(timePrefix) \(suffix)"
        } else {
            return "\(timePrefix) \(baseName)"
        }
    }
    
    private func getTimePrefix(_ timeOfDay: TimeOfDay) -> String {
        switch timeOfDay {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Late Night"
        }
    }
    
    private func getActivitySuffix(_ activityType: ActivityType?) -> String? {
        guard let activity = activityType else { return nil }
        
        switch activity {
        case .workout: return "Workout"
        case .study: return "Study Session"
        case .commute: return "Commute"
        case .party: return "Party Mix"
        case .sleep: return "Sleep Sounds"
        case .work: return "Work Flow"
        case .relaxation: return "Relaxation"
        }
    }
    
    private func determineMoodProgression(context: PlaylistContext) -> MoodProgression {
        switch context.energyProgression {
        case .ascending, .descending:
            return .gradual
        case .steady:
            return .plateau
        case .wave:
            return .contrast
        }
    }
}

// MARK: - Extensions

extension MixTape {
    /// Generate a context-based playlist from this mixtape's songs
    func generateContextBasedPlaylist(
        targetMood: Mood,
        timeOfDay: TimeOfDay,
        activityType: ActivityType? = nil,
        energyProgression: EnergyProgression = .steady,
        generator: ContextBasedPlaylistGenerator
    ) -> Playlist {
        
        let context = PlaylistContext(
            mood: targetMood,
            timeOfDay: timeOfDay,
            activityType: activityType,
            duration: nil,
            energyProgression: energyProgression
        )
        
        return generator.generatePlaylist(
            from: self.songsArray,
            context: context
        )
    }
}

extension AudioFeatures {
    /// Enhanced audio features with additional derived properties
    var overallEnergy: Float {
        return (energy + danceability + (tempo / 180.0)) / 3.0
    }
    
    var moodScore: Float {
        return (valence + energy) / 2.0
    }
    
    var focusScore: Float {
        return instrumentalness * (1.0 - speechiness)
    }
}