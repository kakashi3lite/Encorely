//
//  AIIntegrationService.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import CoreData
import AVKit
import CoreML
import NaturalLanguage

/// Central service that coordinates all AI features of the Mixtapes app
class AIIntegrationService: ObservableObject {
    // Child services
    let moodEngine: MoodEngine
    let personalityEngine: PersonalityEngine
    let recommendationEngine: RecommendationEngine
    let audioAnalysisService: AudioAnalysisService
    
    // Analytics tracking
    private var interactionHistory: [InteractionEvent] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Error handling
    private let errorSubject = PassthroughSubject<AppError, Never>()
    var errorPublisher: AnyPublisher<AppError, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    // Model state
    private var moodModel: MLModel?
    private var personalityModel: MLModel?
    private var recommendationModel: MLModel?
    
    // Service configuration
    private let modelUpdateInterval: TimeInterval = 86400 // 24 hours
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 5
    
    @Published var siriIntegrationEnabled: Bool = false
    
    init(context: NSManagedObjectContext) {
        // Initialize child services
        self.moodEngine = MoodEngine()
        self.personalityEngine = PersonalityEngine()
        self.recommendationEngine = RecommendationEngine(context: context)
        self.audioAnalysisService = AudioAnalysisService()
        
        // Connect services
        setupInterServiceCommunication()
        
        // Load initial user data
        do {
            try loadUserPreferences()
        } catch {
            errorSubject.send(.loadFailure(error))
        }
        
        // Setup models
        setupModels()
    }
    
    // MARK: - Service Communication
    
    private func setupInterServiceCommunication() {
        // Wire up the services to communicate with each other
        moodEngine.$currentMood
            .sink { [weak self] mood in
                self?.recommendationEngine.updateMood(mood)
            }
            .store(in: &cancellables)
        
        personalityEngine.$currentPersonality
            .sink { [weak self] personality in
                self?.recommendationEngine.updatePersonality(personality)
            }
            .store(in: &cancellables)
        
        // Subscribe to child service errors
        audioAnalysisService.errorPublisher
            .sink { [weak self] error in
                NotificationCenter.default.post(name: .audioServiceError, object: error)
            }
            .store(in: &cancellables)
            
        moodEngine.errorPublisher
            .sink { [weak self] error in
                NotificationCenter.default.post(name: .aiServiceError, object: error)
            }
            .store(in: &cancellables)
            
        personalityEngine.errorPublisher
            .sink { [weak self] error in
                NotificationCenter.default.post(name: .aiServiceError, object: error)
            }
            .store(in: &cancellables)
            
        recommendationEngine.errorPublisher
            .sink { [weak self] error in
                NotificationCenter.default.post(name: .aiServiceError, object: error)
            }
            .store(in: &cancellables)
    }
    
    private func startPeriodicUpdates() {
        // Update mood based on time of day every hour
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.moodEngine.updateMoodBasedOnTimeOfDay()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - User Preferences
    
    private func loadUserPreferences() throws {
        guard let moodString = UserDefaults.standard.string(forKey: "userMood"),
              let mood = Mood(rawValue: moodString) else {
            throw AppError.loadFailure(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load mood preference"]))
        }
        moodEngine.currentMood = mood
        
        guard let personalityString = UserDefaults.standard.string(forKey: "userPersonality"),
              let personality = PersonalityType(rawValue: personalityString) else {
            throw AppError.loadFailure(NSError(domain: "AIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to load personality preference"]))
        }
        personalityEngine.currentPersonality = personality
    }
    
    func saveUserPreferences() {
        // Save to UserDefaults
        UserDefaults.standard.set(moodEngine.currentMood.rawValue, forKey: "userMood")
        UserDefaults.standard.set(personalityEngine.currentPersonality.rawValue, forKey: "userPersonality")
    }
    
    // Track user interactions for AI learning
    func trackInteraction(type: String, mixtape: MixTape? = nil) {
        let event = InteractionEvent(
            timestamp: Date(),
            type: type,
            mixtapeId: mixtape?.objectID.uriRepresentation().absoluteString,
            mood: moodEngine.currentMood.rawValue,
            personality: personalityEngine.currentPersonality.rawValue
        )
        
        interactionHistory.append(event)
        
        do {
            try processInteraction(event)
        } catch {
            errorSubject.send(.aiServiceUnavailable)
        }
        
        // Periodically save interaction data
        if interactionHistory.count % 10 == 0 {
            do {
                try saveInteractionHistory()
            } catch {
                errorSubject.send(.saveFailure(error))
            }
        }
    }
    
    private func processInteraction(_ event: InteractionEvent) throws {
        // Send the event to each engine for learning/adaptation
        do {
            try personalityEngine.processInteraction(event)
            try moodEngine.processInteraction(event)
            try recommendationEngine.processInteraction(event)
        } catch {
            throw AppError.aiServiceUnavailable
        }
    }
    
    private func saveInteractionHistory() throws {
        // Save interaction history to persistent storage
        // This would typically be done with CoreData or a similar mechanism
        // For now, we'll just keep it in memory
        guard !interactionHistory.isEmpty else {
            throw AppError.insufficientData
        }
    }
    
    // Get personalized mixtape recommendations
    func getPersonalizedRecommendations() -> [MixTape] {
        return recommendationEngine.getRecommendations()
    }
    
    // Detect mood from audio being played
    func detectMoodFromCurrentAudio(player: AVQueuePlayer) {
        guard let currentItem = player.currentItem else {
            errorSubject.send(.audioUnavailable)
            return
        }
        
        audioAnalysisService.installAnalysisTap(on: player)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorSubject.send(.audioProcessingFailed(error))
                    }
                },
                receiveValue: { [weak self] features in
                    guard let self = self else { return }
                    self.moodEngine.detectMoodFromAudioFeatures(
                        tempo: features.tempo,
                        energy: features.energy,
                        valence: features.valence
                    )
                }
            )
            .store(in: &cancellables)
    }
    
    // Get a greeting message based on current mood and personality
    func getPersonalizedGreeting() -> String {
        let timeGreeting = getTimeBasedGreeting()
        let moodComponent = getMoodBasedComponent()
        return "\(timeGreeting)! \(moodComponent)"
    }
    
    private func getTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }
    
    private func getMoodBasedComponent() -> String {
        switch moodEngine.currentMood {
        case .energetic:
            return "Ready to energize your day with some music?"
        case .relaxed:
            return "Time to unwind with some relaxing tunes?"
        case .happy:
            return "Let's keep that positive vibe going!"
        case .melancholic:
            return "How about some music to match your reflective mood?"
        case .focused:
            return "Looking for something to help you concentrate?"
        case .romantic:
            return "In the mood for something with feeling?"
        case .angry:
            return "Need to channel some intensity today?"
        case .neutral:
            return "What would you like to listen to today?"
        }
    }
    
    // Get insights about the user's listening habits
    func getUserInsights() -> String {
        // In a real app, this would analyze actual listening data
        // For now, we'll generate a simple insight based on personality and mood
        
        let personalityInsight: String
        switch personalityEngine.currentPersonality {
        case .explorer:
            personalityInsight = "You enjoy discovering new music regularly."
        case .curator:
            personalityInsight = "You take pride in organizing your music collections."
        case .enthusiast:
            personalityInsight = "You tend to deeply explore your favorite artists."
        case .social:
            personalityInsight = "You often share music with others."
        case .ambient:
            personalityInsight = "You frequently use music as background accompaniment."
        case .analyzer:
            personalityInsight = "You appreciate the technical aspects of your music."
        }
        
        let moodInsight: String
        switch moodEngine.currentMood {
        case .energetic:
            moodInsight = "Today's selections can help maintain your energy."
        case .relaxed:
            moodInsight = "Your current playlist choices promote relaxation."
        case .happy:
            moodInsight = "Your music selections reflect your positive mood."
        case .melancholic:
            moodInsight = "Your playlist supports thoughtful reflection."
        case .focused:
            moodInsight = "The current mixtapes help maintain concentration."
        case .romantic:
            moodInsight = "Your selections have emotional depth today."
        case .angry:
            moodInsight = "Your music choices help channel intense emotions."
        case .neutral:
            moodInsight = "Your current selections are versatile for any activity."
        }
        
        return "\(personalityInsight) \(moodInsight)"
    }
    
    // Analyze a song to determine its mood
    func analyzeSong(_ song: Song, completion: @escaping (Mood) -> Void) {
        audioAnalysisService.classifySong(song) { mood in
            completion(mood)
        }
    }
    
    // Generate AI mixtape based on mood
    func generateMoodMixtape(mood: Mood, context: NSManagedObjectContext) throws -> MixTape {
        // In a real implementation, this would use sophisticated algorithms
        // to select and arrange songs based on mood analysis
        
        // For now, we'll create a simple MixTape object
        guard let mixtape = try? recommendationEngine.generateMixtape(forMood: mood) else {
            throw AppError.aiServiceUnavailable
        }
        
        mixtape.title = "\(mood.rawValue) Mix"
        mixtape.moodTags = mood.rawValue
        mixtape.aiGenerated = true
        
        return mixtape
    }
    
    // Analyze a collection of songs to detect dominant mood
    func analyzeMixtape(_ mixtape: MixTape, completion: @escaping (Mood) -> Void) {
        // Get all songs in mixtape
        let songs = mixtape.songsArray
        
        // Keep track of analyzed songs
        var analyzedCount = 0
        var moodCounts: [Mood: Int] = [:]
        
        // If no songs, return neutral
        if songs.isEmpty {
            completion(.neutral)
            return
        }
        
        // Analyze each song
        for song in songs {
            analyzeSong(song) { mood in
                // Increment mood count
                if let count = moodCounts[mood] {
                    moodCounts[mood] = count + 1
                } else {
                    moodCounts[mood] = 1
                }
                
                // Increment analyzed count
                analyzedCount += 1
                
                // Check if all songs analyzed
                if analyzedCount == songs.count {
                    // Find most common mood
                    if let dominantMood = moodCounts.max(by: { $0.value < $1.value })?.key {
                        // Update mixtape mood tags
                        mixtape.moodTags = dominantMood.rawValue
                        
                        // Call completion handler
                        completion(dominantMood)
                    } else {
                        // Default to neutral if no dominant mood
                        completion(.neutral)
                    }
                }
            }
        }
    }
    
    // Generate visualization data for audio analysis
    func generateVisualizationData(from audioFeatures: AudioFeatures) -> [Float] {
        // In a real implementation, this would return meaningful data
        // for visualization of audio features
        
        // For now, we'll return a simulated array of values
        return [
            audioFeatures.energy,
            audioFeatures.valence,
            audioFeatures.danceability,
            audioFeatures.acousticness,
            audioFeatures.instrumentalness,
            audioFeatures.speechiness,
            audioFeatures.liveness,
            Float(audioFeatures.tempo) / 200.0 // Normalize tempo to 0-1 range
        ]
    }
    
    // MARK: - Public Interface
    
    /// Generate mood-based song recommendations
    func generateRecommendations(from mood: Mood, count: Int) async throws -> [Song] {
        guard let model = moodModel else {
            errorSubject.send(.modelNotReady)
            throw AppError.modelNotReady
        }
        
        do {
            let predictions = try await withThrowingTaskGroup(of: Song.self) { group in
                for _ in 0..<count {
                    group.addTask {
                        try await self.generateSingleRecommendation(using: model, mood: mood)
                    }
                }
                
                var songs: [Song] = []
                for try await song in group {
                    songs.append(song)
                }
                return songs
            }
            
            return predictions
            
        } catch {
            errorSubject.send(.aiPredictionFailed(error))
            throw error
        }
    }
    
    /// Analyze personality traits from listening history
    func analyzePersonality(from history: [Song]) async throws -> PersonalityProfile {
        guard let model = personalityModel else {
            errorSubject.send(.modelNotReady)
            throw AppError.modelNotReady
        }
        
        do {
            return try await performPersonalityAnalysis(using: model, history: history)
        } catch {
            errorSubject.send(.aiAnalysisFailed(error))
            throw error
        }
    }
    
    /// Generate playlist description
    func generateDescription(for songs: [Song], mood: Mood) async throws -> String {
        let nlModel = NLModel()
        
        do {
            return try await withRetries {
                try await nlModel.generateDescription(songs: songs, mood: mood)
            }
        } catch {
            errorSubject.send(.aiGenerationFailed(error))
            throw error
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupModels() {
        Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    // Load mood model
                    group.addTask {
                        self.moodModel = try await self.loadModel(named: "MoodPrediction")
                    }
                    
                    // Load personality model
                    group.addTask {
                        self.personalityModel = try await self.loadModel(named: "PersonalityAnalysis")
                    }
                    
                    // Load recommendation model
                    group.addTask {
                        self.recommendationModel = try await self.loadModel(named: "SongRecommendation")
                    }
                    
                    try await group.waitForAll()
                }
                
                // Schedule model updates
                scheduleModelUpdates()
                
            } catch {
                errorSubject.send(.modelLoadingFailed(error))
            }
        }
    }
    
    private func loadModel(named name: String) async throws -> MLModel {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            let modelURL = try await downloadLatestModel(named: name)
            return try MLModel(contentsOf: modelURL, configuration: config)
            
        } catch {
            errorSubject.send(.modelLoadingFailed(error))
            throw error
        }
    }
    
    private func downloadLatestModel(named name: String) async throws -> URL {
        let fileManager = FileManager.default
        let cacheDir = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let modelURL = cacheDir.appendingPathComponent("\(name).mlmodel")
        
        // Check if we need to update
        if let attributes = try? fileManager.attributesOfItem(atPath: modelURL.path),
           let modificationDate = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modificationDate) < modelUpdateInterval {
            return modelURL
        }
        
        // Download updated model
        do {
            let (downloadURL, _) = try await URLSession.shared.download(from: getModelEndpoint(name))
            try fileManager.moveItem(at: downloadURL, to: modelURL)
            return modelURL
            
        } catch {
            errorSubject.send(.modelDownloadFailed(error))
            throw error
        }
    }
    
    private func scheduleModelUpdates() {
        Timer.scheduledTimer(withTimeInterval: modelUpdateInterval, repeats: true) { [weak self] _ in
            self?.setupModels()
        }
    }
    
    private func generateSingleRecommendation(using model: MLModel, mood: Mood) async throws -> Song {
        do {
            let prediction = try model.prediction(from: mood)
            return try await fetchSongDetails(from: prediction)
            
        } catch {
            errorSubject.send(.aiPredictionFailed(error))
            throw error
        }
    }
    
    private func performPersonalityAnalysis(using model: MLModel, history: [Song]) async throws -> PersonalityProfile {
        do {
            let features = try extractFeatures(from: history)
            return try model.prediction(from: features)
            
        } catch {
            errorSubject.send(.aiAnalysisFailed(error))
            throw error
        }
    }
    
    private func extractFeatures(from songs: [Song]) throws -> [String: MLFeatureValue] {
        // Feature extraction implementation
        var features: [String: MLFeatureValue] = [:]
        
        // Genre distribution
        let genres = songs.compactMap { $0.genre }
        let genreCounts = Dictionary(grouping: genres, by: { $0 }).mapValues { Float($0.count) / Float(genres.count) }
        features["genreDistribution"] = MLFeatureValue(dictionary: genreCounts as [String: NSNumber])
        
        // Temporal features
        let timestamps = songs.compactMap { $0.lastPlayed }
        if let earliest = timestamps.min(), let latest = timestamps.max() {
            features["listeningPeriod"] = MLFeatureValue(double: latest.timeIntervalSince(earliest))
        }
        
        // Mood features
        let moods = songs.compactMap { $0.dominantMood?.rawValue }
        let moodCounts = Dictionary(grouping: moods, by: { $0 }).mapValues { Float($0.count) / Float(moods.count) }
        features["moodDistribution"] = MLFeatureValue(dictionary: moodCounts as [String: NSNumber])
        
        return features
    }
    
    private func fetchSongDetails(from prediction: MLFeatureProvider) async throws -> Song {
        // Implementation of fetching actual song details based on model prediction
        do {
            guard let songId = prediction.featureValue(for: "recommendedSongId")?.stringValue else {
                throw AppError.invalidPrediction
            }
            
            return try await withRetries {
                try await fetchSong(byId: songId)
            }
            
        } catch {
            errorSubject.send(.songFetchFailed(error))
            throw error
        }
    }
    
    private func fetchSong(byId id: String) async throws -> Song {
        // Actual API call implementation
        let (data, response) = try await URLSession.shared.data(from: getSongEndpoint(id))
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AppError.invalidResponse
        }
        
        do {
            return try JSONDecoder().decode(Song.self, from: data)
        } catch {
            throw AppError.decodingFailed(error)
        }
    }
    
    private func withRetries<T>(retries: Int = 3, operation: () async throws -> T) async throws -> T {
        var attempts = 0
        var lastError: Error?
        
        while attempts < retries {
            do {
                return try await operation()
            } catch {
                lastError = error
                attempts += 1
                
                if attempts < retries {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? AppError.maxRetriesExceeded
    }
    
    private func getModelEndpoint(_ name: String) -> URL {
        // Implementation to get model download URL
        URL(string: "https://api.aimixtapes.com/models/\(name)")!
    }
    
    private func getSongEndpoint(_ id: String) -> URL {
        // Implementation to get song details API endpoint
        URL(string: "https://api.aimixtapes.com/songs/\(id)")!
    }
    
    // MARK: - Siri Integration
    
    func handleSiriError(_ error: Error, type: String) {
        let siriError = error as NSError
        aiLogger.logError(model: "SiriIntegration", error: .siriError(siriError))
        errorSubject.send(.siriError(siriError))
    }
    
    func validateSiriAuthorization() -> Bool {
        let status = INPreferences.siriAuthorizationStatus()
        return status == .authorized
    }
}

// MARK: - Supporting Types

extension MLModel {
    func prediction(from mood: Mood) throws -> MLFeatureProvider {
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "mood": MLFeatureValue(string: mood.rawValue),
            "confidence": MLFeatureValue(double: 1.0)
        ])
        
        return try prediction(from: input)
    }
    
    func prediction(from features: [String: MLFeatureValue]) throws -> PersonalityProfile {
        let input = try MLDictionaryFeatureProvider(dictionary: features)
        let output = try prediction(from: input)
        
        return PersonalityProfile(
            openness: output.featureValue(for: "openness")?.doubleValue ?? 0,
            conscientiousness: output.featureValue(for: "conscientiousness")?.doubleValue ?? 0,
            extraversion: output.featureValue(for: "extraversion")?.doubleValue ?? 0,
            agreeableness: output.featureValue(for: "agreeableness")?.doubleValue ?? 0,
            neuroticism: output.featureValue(for: "neuroticism")?.doubleValue ?? 0
        )
    }
}

// Model for tracking user interactions
struct InteractionEvent {
    let timestamp: Date
    let type: String
    let mixtapeId: String?
    let mood: String
    let personality: String
    
    // Additional contextual data could be added here
}
