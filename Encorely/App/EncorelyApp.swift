import SwiftUI
import SwiftData

/// Single entry point for the Encorely app.
/// Configures SwiftData model container and injects shared services.
/// Shows onboarding if no SonicProfile exists yet.
@main
struct EncorelyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootGateView()
                .environment(appState.playbackService)
                .environment(appState.moodEngine)
                .environment(appState.personalityEngine)
                .environment(appState.recommendationEngine)
        }
        .modelContainer(appState.modelContainer)
    }
}

/// Decides whether to show onboarding or the main app.
/// Uses SwiftData @Query to check for an existing SonicProfile.
struct RootGateView: View {
    @Query private var profiles: [SonicProfile]

    var body: some View {
        if profiles.isEmpty {
            OnboardingContainerView()
        } else {
            AppTabView()
        }
    }
}

/// Holds all shared app state, initialized once at launch.
/// Separated from EncorelyApp to avoid @State init ordering issues.
@Observable
final class AppState {
    let modelContainer: ModelContainer
    let playbackService: AudioPlaybackService
    let moodEngine: MoodEngine
    let personalityEngine: PersonalityEngine
    let recommendationEngine: RecommendationEngine

    init() {
        let schema = Schema([
            Mixtape.self,
            Song.self,
            UserProfile.self,
            MoodSnapshot.self,
            SonicProfile.self,
        ])

        // Use a do/catch that falls back to in-memory if disk storage fails
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: false)])
        } catch {
            // Fallback to in-memory so the app still launches
            container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        }
        self.modelContainer = container

        self.playbackService = AudioPlaybackService()
        let mood = MoodEngine()
        let personality = PersonalityEngine()
        self.moodEngine = mood
        self.personalityEngine = personality
        self.recommendationEngine = RecommendationEngine(
            moodEngine: mood,
            personalityEngine: personality
        )
    }
}
