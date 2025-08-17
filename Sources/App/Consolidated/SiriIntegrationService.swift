//
//  SiriIntegrationService.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import AVKit
import Combine
import CoreData
import CoreML
import Foundation
import Intents
import IntentsUI

// MARK: - Custom Intent Handlers

final class SiriIntegrationService: NSObject, PlayMoodIntentHandling, CreateMixtapeIntentHandling,
    AnalyzeCurrentSongIntentHandling
{
    static let shared = SiriIntegrationService()

    // Services
    private let moodEngine: MoodEngine
    private let aiService: AIIntegrationService
    private let aiLogger: AILogger
    private var player: AVQueuePlayer
    private var moc: NSManagedObjectContext
    private var subscriptions = Set<AnyCancellable>()

    init(aiService: AIIntegrationService, player: AVQueuePlayer, context: NSManagedObjectContext) {
        self.aiService = aiService
        moodEngine = aiService.moodEngine
        self.player = player
        moc = context
        aiLogger = AILogger.shared
        super.init()
        setupShortcuts()
    }

    // MARK: - Intent Handling

    func handle(intent: PlayMoodIntent, completion: @escaping (PlayMoodIntentResponse) -> Void) {
        guard let moodString = intent.mood?.identifier,
              let mood = Mood(rawValue: moodString)
        else {
            completion(PlayMoodIntentResponse(code: .failure, userActivity: nil))
            return
        }

        playMoodBasedMixtape(mood)
        let response = PlayMoodIntentResponse(code: .success, userActivity: nil)
        response.spokenResponse = "Playing \(mood.rawValue.lowercased()) music"
        completion(response)
    }

    func handle(intent: CreateMixtapeIntent, completion: @escaping (CreateMixtapeIntentResponse) -> Void) {
        guard let moodString = intent.mood?.identifier,
              let mood = Mood(rawValue: moodString)
        else {
            completion(CreateMixtapeIntentResponse(code: .failure, userActivity: nil))
            return
        }

        let newMixtape = aiService.generateMoodMixtape(mood: mood, context: moc)

        do {
            try moc.save()
            let response = CreateMixtapeIntentResponse(code: .success, userActivity: nil)
            response.spokenResponse = "Created a \(mood.rawValue.lowercased()) mixtape"
            completion(response)
        } catch {
            completion(CreateMixtapeIntentResponse(code: .failure, userActivity: nil))
        }
    }

    func handle(intent _: AnalyzeCurrentSongIntent, completion: @escaping (AnalyzeCurrentSongIntentResponse) -> Void) {
        guard player.currentItem != nil else {
            let response = AnalyzeCurrentSongIntentResponse(code: .failure, userActivity: nil)
            response.spokenResponse = "No song is currently playing"
            completion(response)
            return
        }

        aiService.detectMoodFromCurrentAudio(player: player)
        let response = AnalyzeCurrentSongIntentResponse(code: .success, userActivity: nil)
        response.spokenResponse = "Analyzing your current song for mood and features"
        completion(response)
    }

    // MARK: - Parameter Resolution

    func resolveMood(for intent: PlayMoodIntent, with completion: @escaping (MoodParameterResolutionResult) -> Void) {
        guard let mood = intent.mood else {
            completion(.needsValue())
            return
        }
        completion(.success(with: mood))
    }

    // MARK: - Shortcut Donation

    func donateShortcuts() {
        // Donate Play Mood shortcuts
        for mood in Mood.allCases {
            let intent = PlayMoodIntent()
            intent.mood = MoodParameter(identifier: mood.rawValue, display: mood.rawValue)
            intent.suggestedInvocationPhrase = "Play \(mood.rawValue.lowercased()) music"

            let interaction = INInteraction(intent: intent, response: nil)
            interaction.donate { error in
                if let error {
                    print("Failed to donate shortcut: \(error)")
                }
            }
        }

        // Donate Create Mixtape shortcut
        let createIntent = CreateMixtapeIntent()
        createIntent.suggestedInvocationPhrase = "Create a mixtape"

        let createInteraction = INInteraction(intent: createIntent, response: nil)
        createInteraction.donate(completion: nil)

        // Donate Analyze shortcut
        let analyzeIntent = AnalyzeCurrentSongIntent()
        analyzeIntent.suggestedInvocationPhrase = "Analyze this song"

        let analyzeInteraction = INInteraction(intent: analyzeIntent, response: nil)
        analyzeInteraction.donate(completion: nil)
    }

    // MARK: - Private Methods

    private func playMoodBasedMixtape(_ mood: Mood) {
        // Implementation to play mood-based music
        aiService.moodEngine.setMood(mood, confidence: 0.9)
        // Additional implementation...
    }

    private func setupShortcuts() {
        // Register dynamic shortcuts
        let shortcuts = Mood.allCases.map { mood in
            let intent = PlayMoodIntent()
            intent.mood = MoodParameter(identifier: mood.rawValue, display: mood.rawValue)
            return INShortcut(intent: intent)
        }

        INVoiceShortcutCenter.shared.setShortcutSuggestions(shortcuts)
    }
}

// MARK: - Siri Audio Authorization

extension SiriIntegrationService {
    static func requestSiriAuthorization(completion: @escaping (Bool) -> Void) {
        INPreferences.requestSiriAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }
}

/// Extension for the MoodEngine to support Siri parameters
extension MoodEngine {
    /// Convert a Siri parameter value to a Mood
    func moodFromSiriParameter(_ parameter: Double) -> Mood {
        // Map numeric parameter (0-1) to moods
        if parameter < 0.15 {
            .melancholic
        } else if parameter < 0.3 {
            .relaxed
        } else if parameter < 0.45 {
            .neutral
        } else if parameter < 0.6 {
            .focused
        } else if parameter < 0.75 {
            .happy
        } else if parameter < 0.9 {
            .romantic
        } else {
            .energetic
        }
    }

    /// Set mood from Siri with parameter
    func setMoodFromSiri(parameter: Double) {
        let mood = moodFromSiriParameter(parameter)
        setMood(mood, confidence: 0.8)
    }
}

/// View controller for demonstrating Siri shortcuts
class SiriShortcutsViewController: UIViewController, INUIAddVoiceShortcutViewControllerDelegate,
    INUIEditVoiceShortcutViewControllerDelegate
{
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
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
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
        button.setTitle("Add " \ title" to Siri", for: .normal)
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
        intent.mediaItems = [INMediaItem(
            identifier: identifier,
            title: sender.title(for: .normal) ?? "",
            type: .music,
            artwork: nil
        )]

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
        case "play_mood_energetic": "Play something energizing"
        case "play_mood_relaxed": "Play something relaxing"
        case "create_mood_focused": "Create a focus mixtape"
        case "analyze_current_song": "Analyze this song"
        case "show_insights": "Show my music insights"
        default: "Play music"
        }
    }

    // MARK: - INUIAddVoiceShortcutViewControllerDelegate

    func addVoiceShortcutViewController(
        _ controller: INUIAddVoiceShortcutViewController,
        didFinishWith _: INVoiceShortcut?,
        error: Error?
    ) {
        controller.dismiss(animated: true, completion: nil)

        if let error {
            // Handle error
            print("Error adding shortcut: \(error)")
        }
    }

    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        controller.dismiss(animated: true, completion: nil)
    }

    // MARK: - INUIEditVoiceShortcutViewControllerDelegate

    func editVoiceShortcutViewController(
        _ controller: INUIEditVoiceShortcutViewController,
        didUpdate _: INVoiceShortcut?,
        error: Error?
    ) {
        controller.dismiss(animated: true, completion: nil)

        if let error {
            // Handle error
            print("Error updating shortcut: \(error)")
        }
    }

    func editVoiceShortcutViewController(
        _ controller: INUIEditVoiceShortcutViewController,
        didDeleteVoiceShortcutWithIdentifier _: UUID
    ) {
        controller.dismiss(animated: true, completion: nil)
    }

    func editVoiceShortcutViewControllerDidCancel(_ controller: INUIEditVoiceShortcutViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}

// MARK: - SwiftUI Bridge
// SiriShortcutsView is defined in SiriShortcutsView.swift
