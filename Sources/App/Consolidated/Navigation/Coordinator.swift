//
//  Coordinator.swift
//  AI-Mixtapes
//
//  Created by Navigation Specialist on 05/30/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import AppKit
import Combine
import CoreData
import SwiftUI

// MARK: - Navigation Destination

enum NavigationDestination: Hashable {
    case mixtapeDetail(MixTape)
    case aiGenerator
    case personalityProfile
    case moodSelector
    case audioAnalysis
    case insights
    case settings
    case onboarding
}

// MARK: - Navigation Coordinator Protocol

protocol NavigationCoordinator: ObservableObject {
    var selectedTab: Int { get set }
    var navigationPath: NavigationPath { get set }
    var showingOnboarding: Bool { get set }
    var showingMoodSelector: Bool { get set }
    var showingPersonalitySettings: Bool { get set }

    func navigate(to destination: NavigationDestination)
    func navigateToTab(_ tab: Int)
    func presentSheet(_ sheet: SheetDestination)
    func dismissSheet()
}

enum SheetDestination {
    case onboarding
    case moodSelector
    case personalitySettings
    case aiGenerator
    case settings
}

// MARK: - Dependency Injection Container

class ViewDIContainer: ObservableObject {
    // Core Data
    lazy var persistenceController = PersistenceController.shared
    var context: NSManagedObjectContext { persistenceController.container.viewContext }

    // AI Services
    lazy var aiService = AIIntegrationService(context: context)

    // Audio Services
    lazy var audioProcessor = AudioProcessor()

    // Error Handling
    lazy var errorCoordinator = ErrorCoordinator.shared

    init() {
        setupServices()
    }

    private func setupServices() {
        // Initialize AI services with proper dependencies
        aiService.audioAnalysisService.audioProcessor = audioProcessor
    }
}

// MARK: - App Coordinator

@MainActor
class AppCoordinator: NavigationCoordinator {
    // MARK: - Published Properties

    @Published var selectedTab: Int = 0
    @Published var navigationPath = NavigationPath()
    @Published var showingOnboarding: Bool = false
    @Published var showingMoodSelector: Bool = false
    @Published var showingPersonalitySettings: Bool = false
    @Published var showingAIGenerator: Bool = false
    @Published var showingSettings: Bool = false

    // MARK: - Dependencies

    private let container: ViewDIContainer
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(container: ViewDIContainer = ViewDIContainer()) {
        self.container = container
        setupNavigationBindings()
        checkOnboardingStatus()
    }

    // MARK: - Public Methods

    func run(in window: UIWindow?) {
        guard let window else {
            print("❌ AppCoordinator: No window provided")
            return
        }

        let rootView = createRootView()
        let hostingController = UIHostingController(rootView: rootView)

        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        // Track app launch
        container.aiService.trackInteraction(type: "app_launched")

        print("✅ AppCoordinator: App launched successfully")
    }

    func navigate(to destination: NavigationDestination) {
        switch destination {
        case let .mixtapeDetail(mixtape):
            navigationPath.append(destination)
            container.aiService.trackInteraction(type: "navigate_to_mixtape", mixtape: mixtape)

        case .aiGenerator:
            selectedTab = 1 // AI Generate tab
            container.aiService.trackInteraction(type: "navigate_to_ai_generator")

        case .personalityProfile:
            showingPersonalitySettings = true
            container.aiService.trackInteraction(type: "navigate_to_personality")

        case .moodSelector:
            showingMoodSelector = true
            container.aiService.trackInteraction(type: "navigate_to_mood_selector")

        case .audioAnalysis:
            selectedTab = 2 // Audio Analysis tab
            container.aiService.trackInteraction(type: "navigate_to_audio_analysis")

        case .insights:
            selectedTab = 3 // Insights tab
            container.aiService.trackInteraction(type: "navigate_to_insights")

        case .settings:
            showingSettings = true
            container.aiService.trackInteraction(type: "navigate_to_settings")

        case .onboarding:
            showingOnboarding = true
            container.aiService.trackInteraction(type: "navigate_to_onboarding")
        }
    }

    func navigateToTab(_ tab: Int) {
        guard tab >= 0, tab <= 4 else { return }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedTab = tab
        }

        // Clear navigation path when switching tabs
        if !navigationPath.isEmpty {
            navigationPath = NavigationPath()
        }

        let tabNames = ["library", "generate", "analyze", "insights", "settings"]
        container.aiService.trackInteraction(type: "navigate_to_tab_\(tabNames[tab])")
    }

    func presentSheet(_ sheet: SheetDestination) {
        switch sheet {
        case .onboarding:
            showingOnboarding = true
        case .moodSelector:
            showingMoodSelector = true
        case .personalitySettings:
            showingPersonalitySettings = true
        case .aiGenerator:
            showingAIGenerator = true
        case .settings:
            showingSettings = true
        }
    }

    func dismissSheet() {
        showingOnboarding = false
        showingMoodSelector = false
        showingPersonalitySettings = false
        showingAIGenerator = false
        showingSettings = false
    }

    // MARK: - Private Methods

    private func createRootView() -> some View {
        MainTabView(
            queuePlayer: container.aiService.queuePlayer,
            playerItemObserver: container.aiService.playerItemObserver,
            playerStatusObserver: container.aiService.playerStatusObserver,
            currentPlayerItems: container.aiService.currentPlayerItems,
            currentSongName: container.aiService.currentSongName,
            isPlaying: container.aiService.isPlaying,
            aiService: container.aiService,
            coordinator: self
        )
        .environment(\.managedObjectContext, container.context)
        .environmentObject(container.aiService)
        .environmentObject(container.errorCoordinator)
        .navigationDestination(for: NavigationDestination.self) { destination in
            destinationView(for: destination)
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView(
                personalityEngine: container.aiService.personalityEngine,
                isShowingOnboarding: $showingOnboarding
            )
        }
        .sheet(isPresented: $showingMoodSelector) {
            MoodView(moodEngine: container.aiService.moodEngine)
        }
        .sheet(isPresented: $showingPersonalitySettings) {
            PersonalityView(personalityEngine: container.aiService.personalityEngine)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(aiService: container.aiService)
        }
        .withErrorHandling()
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case let .mixtapeDetail(mixtape):
            MixTapeView(
                songs: mixtape.songsArray,
                mixTape: mixtape,
                currentMixTapeName: .constant(mixtape.wrappedTitle),
                currentMixTapeImage: .constant(mixtape.wrappedUrl),
                queuePlayer: container.aiService.queuePlayer,
                currentStatusObserver: container.aiService.playerStatusObserver,
                currentItemObserver: container.aiService.playerItemObserver,
                currentPlayerItems: container.aiService.currentPlayerItems,
                currentSongName: container.aiService.currentSongName,
                isPlaying: container.aiService.isPlaying,
                aiService: container.aiService
            )
            .environment(\.managedObjectContext, container.context)

        case .aiGenerator:
            AIGeneratedMixtapeView(aiService: container.aiService)
                .environment(\.managedObjectContext, container.context)

        case .personalityProfile:
            PersonalityView(personalityEngine: container.aiService.personalityEngine)

        case .moodSelector:
            MoodView(moodEngine: container.aiService.moodEngine)

        case .audioAnalysis:
            AudioVisualizationView(
                queuePlayer: container.aiService.queuePlayer,
                aiService: container.aiService,
                currentSongName: container.aiService.currentSongName
            )

        case .insights:
            InsightsDashboardView(aiService: container.aiService)
                .environment(\.managedObjectContext, container.context)

        case .settings:
            SettingsView(aiService: container.aiService)

        case .onboarding:
            OnboardingView(
                personalityEngine: container.aiService.personalityEngine,
                isShowingOnboarding: $showingOnboarding
            )
        }
    }

    private func setupNavigationBindings() {
        // Listen for AI-triggered navigation events
        NotificationCenter.default.publisher(for: .navigateToDestination)
            .compactMap { $0.object as? NavigationDestination }
            .sink { [weak self] destination in
                self?.navigate(to: destination)
            }
            .store(in: &cancellables)

        // Listen for tab change requests
        NotificationCenter.default.publisher(for: .navigateToTab)
            .compactMap { $0.object as? Int }
            .sink { [weak self] tab in
                self?.navigateToTab(tab)
            }
            .store(in: &cancellables)

        // Listen for mixtape creation completion
        NotificationCenter.default.publisher(for: .mixtapeCreated)
            .compactMap { $0.object as? MixTape }
            .sink { [weak self] mixtape in
                // Navigate to library tab and show the new mixtape
                self?.navigateToTab(0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.navigate(to: .mixtapeDetail(mixtape))
                }
            }
            .store(in: &cancellables)
    }

    private func checkOnboardingStatus() {
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            showingOnboarding = true
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let navigateToDestination = Notification.Name("navigateToDestination")
    static let navigateToTab = Notification.Name("navigateToTab")
    static let mixtapeCreated = Notification.Name("mixtapeCreated")
}

// MARK: - Navigation Helper Extensions

extension AppCoordinator {
    /// Navigate to a specific mixtape by ID
    func navigateToMixtape(id: NSManagedObjectID) {
        do {
            let mixtape = try container.context.existingObject(with: id) as? MixTape
            if let mixtape {
                navigate(to: .mixtapeDetail(mixtape))
            }
        } catch {
            print("❌ Failed to load mixtape with ID: \(id)")
            container.errorCoordinator.handle(.entityNotFound("MixTape"))
        }
    }

    /// Quick navigation methods for common flows
    func showAIGenerator(for mood: Mood? = nil) {
        if let mood {
            container.aiService.moodEngine.setMood(mood, confidence: 0.8)
        }
        navigate(to: .aiGenerator)
    }

    func showInsightsForMood(_ mood: Mood) {
        container.aiService.moodEngine.setMood(mood, confidence: 0.9)
        navigate(to: .insights)
    }

    /// Deep linking support
    func handleDeepLink(_ url: URL) {
        // Parse URL and navigate accordingly
        // Example: ai-mixtapes://mixtape/123 or ai-mixtapes://mood/energetic

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let host = components?.host else { return }

        switch host {
        case "mixtape":
            if let idString = components?.path.dropFirst().description,
               let objectURL = URL(string: "x-coredata://\(idString)"),
               let coordinator = container.persistenceController.container.persistentStoreCoordinator
               .managedObjectID(forURIRepresentation: objectURL)
            {
                navigateToMixtape(id: coordinator)
            }

        case "mood":
            if let moodString = components?.path.dropFirst().description,
               let mood = Mood(rawValue: moodString)
            {
                showAIGenerator(for: mood)
            }

        case "tab":
            if let tabString = components?.path.dropFirst().description,
               let tabIndex = Int(tabString)
            {
                navigateToTab(tabIndex)
            }

        default:
            break
        }

        container.aiService.trackInteraction(type: "deep_link_\(host)")
    }
}

// MARK: - Preview Support

#if DEBUG
    extension ViewDIContainer {
        static let preview: DIContainer = {
            let container = ViewDIContainer()
            // Add any preview-specific setup here
            return container
        }()
    }

    extension AppCoordinator {
        static let preview: AppCoordinator = .init(container: .preview)
    }
#endif
