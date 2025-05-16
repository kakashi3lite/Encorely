//
//  SiriIntegrationService.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import Intents
import IntentsUI
import AVKit
import CoreData

/// Service for integrating with SiriKit to enable voice commands for AI Mixtapes
class SiriIntegrationService: NSObject, INPlayMediaIntentHandling {
    // Core services
    private let aiService: AIIntegrationService
    private let moc: NSManagedObjectContext
    private let player: AVQueuePlayer
    
    // Intent handlers
    private var handlers: [String: () -> Void] = [:]
    
    init(aiService: AIIntegrationService, moc: NSManagedObjectContext, player: AVQueuePlayer) {
        self.aiService = aiService
        self.moc = moc
        self.player = player
        
        super.init()
        
        setupIntentHandlers()
        setupSiriShortcuts()
    }
    
    /// Setup handlers for common voice commands
    private func setupIntentHandlers() {
        // Command: Play music for [mood]
        handlers["play_mood_energetic"] = { self.playMoodBasedMixtape(.energetic) }
        handlers["play_mood_relaxed"] = { self.playMoodBasedMixtape(.relaxed) }
        handlers["play_mood_happy"] = { self.playMoodBasedMixtape(.happy) }
        handlers["play_mood_melancholic"] = { self.playMoodBasedMixtape(.melancholic) }
        handlers["play_mood_focused"] = { self.playMoodBasedMixtape(.focused) }
        handlers["play_mood_romantic"] = { self.playMoodBasedMixtape(.romantic) }
        handlers["play_mood_angry"] = { self.playMoodBasedMixtape(.angry) }
        
        // Command: Create a [mood] mixtape
        handlers["create_mood_energetic"] = { self.createMoodBasedMixtape(.energetic) }
        handlers["create_mood_relaxed"] = { self.createMoodBasedMixtape(.relaxed) }
        handlers["create_mood_happy"] = { self.createMoodBasedMixtape(.happy) }
        handlers["create_mood_melancholic"] = { self.createMoodBasedMixtape(.melancholic) }
        handlers["create_mood_focused"] = { self.createMoodBasedMixtape(.focused) }
        handlers["create_mood_romantic"] = { self.createMoodBasedMixtape(.romantic) }
        handlers["create_mood_angry"] = { self.createMoodBasedMixtape(.angry) }
        
        // Command: Analyze current song
        handlers["analyze_current_song"] = { self.analyzeCurrentSong() }
        
        // Command: Show insights
        handlers["show_insights"] = { self.showInsights() }
    }
    
    /// Setup predefined Siri shortcuts
    private func setupSiriShortcuts() {
        // Common shortcuts for users to add
        donateShortcut(for: "Play energizing music", with: "play_mood_energetic", suggestedPhrase: "Play something energizing")
        donateShortcut(for: "Play relaxing music", with: "play_mood_relaxed", suggestedPhrase: "Play something relaxing")
        donateShortcut(for: "Play happy music", with: "play_mood_happy", suggestedPhrase: "Play happy music")
        donateShortcut(for: "Create focused mixtape", with: "create_mood_focused", suggestedPhrase: "Create a focus mixtape")
        donateShortcut(for: "Analyze this song", with: "analyze_current_song", suggestedPhrase: "Analyze this song")
        donateShortcut(for: "Show my music insights", with: "show_insights", suggestedPhrase: "Show my music insights")
    }
    
    /// Donate a shortcut to Siri
    private func donateShortcut(for activity: String, with identifier: String, suggestedPhrase: String) {
        let intent = INPlayMediaIntent()
        intent.mediaItems = [INMediaItem(identifier: identifier, title: activity, type: .music, artwork: nil)]
        intent.suggestedInvocationPhrase = suggestedPhrase
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("SiriIntegration - Failed to donate shortcut: \(error)")
            }
        }
    }
    
    // MARK: - Intent Handling
    
    /// Handle "play media" intents from Siri
    func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        // Extract the command from the media identifier
        if let mediaItems = intent.mediaItems, let firstItem = mediaItems.first, let identifier = firstItem.identifier {
            // Check if we have a handler for this command
            if let handler = handlers[identifier] {
                // Execute the command
                handler()
                
                // Return success response
                let response = INPlayMediaIntentResponse(code: .success, userActivity: nil)
                completion(response)
                
                // Track interaction
                aiService.trackInteraction(type: "siri_command_\(identifier)")
                
                return
            }
        }
        
        // Handle generic play command (play whatever is appropriate)
        playRecommendedMixtape()
        
        // Return success response
        let response = INPlayMediaIntentResponse(code: .success, userActivity: nil)
        completion(response)
    }
    
    // MARK: - Command Implementations
    
    /// Play a mixtape based on specified mood
    private func playMoodBasedMixtape(_ mood: Mood) {
        // Find mixtapes that match this mood
        let fetchRequest: NSFetchRequest<MixTape> = MixTape.fetchRequest()
        
        // Filter by mood tags if available
        fetchRequest.predicate = NSPredicate(format: "moodTags CONTAINS[cd] %@", mood.rawValue)
        
        do {
            let matchingTapes = try moc.fetch(fetchRequest)
            
            if let mixtape = matchingTapes.first {
                // Play the mixtape
                playMixtape(mixtape)
            } else {
                // No matching mixtape, create one
                let newMixtape = aiService.generateMoodMixtape(mood: mood, context: moc)
                
                // In a real app, we would populate this with songs
                // For now, just save it
                try? moc.save()
                
                // Play a fallback
                playRecommendedMixtape()
            }
        } catch {
            print("SiriIntegration - Error fetching mixtapes: \(error)")
            playRecommendedMixtape()
        }
    }
    
    /// Create a new mixtape for a specific mood
    private func createMoodBasedMixtape(_ mood: Mood) {
        // Generate a new mixtape
        let newMixtape = aiService.generateMoodMixtape(mood: mood, context: moc)
        
        // Save to CoreData
        do {
            try moc.save()
            
            // Track interaction
            aiService.trackInteraction(type: "siri_create_mixtape_\(mood.rawValue)")
        } catch {
            print("SiriIntegration - Error saving mixtape: \(error)")
        }
    }
    
    /// Analyze the currently playing song
    private func analyzeCurrentSong() {
        // In a real app, this would trigger the audio analysis
        // For now, just track the interaction
        aiService.trackInteraction(type: "siri_analyze_current_song")
    }
    
    /// Show the insights dashboard
    private func showInsights() {
        // In a real app, this would navigate to the insights view
        // For now, just track the interaction
        aiService.trackInteraction(type: "siri_show_insights")
    }
    
    /// Play a recommended mixtape
    private func playRecommendedMixtape() {
        // Get recommendations from the AI service
        let recommendations = aiService.getPersonalizedRecommendations()
        
        if let mixtape = recommendations.first {
            // Play the mixtape
            playMixtape(mixtape)
        } else {
            // No recommendations, play the first available mixtape
            let fetchRequest: NSFetchRequest<MixTape> = MixTape.fetchRequest()
            
            do {
                let mixtapes = try moc.fetch(fetchRequest)
                if let mixtape = mixtapes.first {
                    playMixtape(mixtape)
                }
            } catch {
                print("SiriIntegration - Error fetching mixtapes: \(error)")
            }
        }
    }
    
    /// Play a specific mixtape
    private func playMixtape(_ mixtape: MixTape) {
        // Create player items for all songs
        let playerItems = createArrayOfPlayerItems(songs: mixtape.songsArray)
        
        // Load and play
        player.removeAllItems()
        for item in playerItems {
            player.insert(item, after: nil)
        }
        player.play()
        
        // Track play in mixtape model
        mixtape.trackPlay()
        try? moc.save()
        
        // Track interaction
        aiService.trackInteraction(type: "siri_play_mixtape", mixtape: mixtape)
    }
}

// MARK: - SiriKit Intent Extensions

/// Extension for the MoodEngine to support Siri parameters
extension MoodEngine {
    /// Convert a Siri parameter value to a Mood
    func moodFromSiriParameter(_ parameter: Double) -> Mood {
        // Map numeric parameter (0-1) to moods
        if parameter < 0.15 {
            return .melancholic
        } else if parameter < 0.3 {
            return .relaxed
        } else if parameter < 0.45 {
            return .neutral
        } else if parameter < 0.6 {
            return .focused
        } else if parameter < 0.75 {
            return .happy
        } else if parameter < 0.9 {
            return .romantic
        } else {
            return .energetic
        }
    }
    
    /// Set mood from Siri with parameter
    func setMoodFromSiri(parameter: Double) {
        let mood = moodFromSiriParameter(parameter)
        setMood(mood, confidence: 0.8)
    }
}

/// View controller for demonstrating Siri shortcuts
class SiriShortcutsViewController: UIViewController, INUIAddVoiceShortcutViewControllerDelegate, INUIEditVoiceShortcutViewControllerDelegate {
    // MARK: - Properties
    
    private var siriIntegration: SiriIntegrationService?
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup UI
        setupUI()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Configure view
        view.backgroundColor = .systemBackground
        title = "Siri Shortcuts"
        
        // Add shortcut buttons
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        // Constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        // Add shortcut buttons
        addShortcutButton(to: stackView, title: "Play energizing music", identifier: "play_mood_energetic")
        addShortcutButton(to: stackView, title: "Play relaxing music", identifier: "play_mood_relaxed")
        addShortcutButton(to: stackView, title: "Create focused mixtape", identifier: "create_mood_focused")
        addShortcutButton(to: stackView, title: "Analyze current song", identifier: "analyze_current_song")
        addShortcutButton(to: stackView, title: "Show music insights", identifier: "show_insights")
    }
    
    // MARK: - Shortcut Helpers
    
    private func addShortcutButton(to stackView: UIStackView, title: String, identifier: String) {
        let button = UIButton(type: .system)
        button.setTitle("Add "\(title)" to Siri", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        
        // Set tag with identifier for retrieval
        button.accessibilityIdentifier = identifier
        
        // Add action
        button.addTarget(self, action: #selector(addShortcutTapped(_:)), for: .touchUpInside)
        
        stackView.addArrangedSubview(button)
    }
    
    // MARK: - Actions
    
    @objc private func addShortcutTapped(_ sender: UIButton) {
        guard let identifier = sender.accessibilityIdentifier else { return }
        
        // Create intent
        let intent = INPlayMediaIntent()
        intent.mediaItems = [INMediaItem(identifier: identifier, title: sender.title(for: .normal) ?? "", type: .music, artwork: nil)]
        
        // Suggest invocation phrase based on identifier
        let phrase = getSuggestedPhrase(for: identifier)
        intent.suggestedInvocationPhrase = phrase
        
        // Present add shortcut UI
        let viewController = INUIAddVoiceShortcutViewController(shortcut: INShortcut(intent: intent))
        viewController.delegate = self
        present(viewController, animated: true, completion: nil)
    }
    
    // MARK: - Helpers
    
    private func getSuggestedPhrase(for identifier: String) -> String {
        switch identifier {
        case "play_mood_energetic": return "Play something energizing"
        case "play_mood_relaxed": return "Play something relaxing"
        case "create_mood_focused": return "Create a focus mixtape"
        case "analyze_current_song": return "Analyze this song"
        case "show_insights": return "Show my music insights"
        default: return "Play music"
        }
    }
    
    // MARK: - INUIAddVoiceShortcutViewControllerDelegate
    
    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
        
        if let error = error {
            // Handle error
            print("Error adding shortcut: \(error)")
        }
    }
    
    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - INUIEditVoiceShortcutViewControllerDelegate
    
    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController, didUpdate voiceShortcut: INVoiceShortcut?, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
        
        if let error = error {
            // Handle error
            print("Error updating shortcut: \(error)")
        }
    }
    
    func editVoiceShortcutViewController(_ controller: INUIEditVoiceShortcutViewController, didDeleteVoiceShortcutWithIdentifier deletedVoiceShortcutIdentifier: UUID) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    func editVoiceShortcutViewControllerDidCancel(_ controller: INUIEditVoiceShortcutViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}

// MARK: - SwiftUI Bridge

/// SwiftUI wrapper for the Siri shortcuts view controller
struct SiriShortcutsView: UIViewControllerRepresentable {
    var aiService: AIIntegrationService
    
    func makeUIViewController(context: Context) -> SiriShortcutsViewController {
        let viewController = SiriShortcutsViewController()
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: SiriShortcutsViewController, context: Context) {
        // Update if needed
    }
}
