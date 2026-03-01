import SwiftUI

/// Root tab view with four tabs and a persistent mini-player overlay.
struct AppTabView: View {
    @State private var selectedTab: Tab = .library
    @Environment(AudioPlaybackService.self) private var playbackService

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                libraryTab
                generateTab
                analyzeTab
                profileTab
            }

            // Persistent mini-player above the tab bar
            if playbackService.isPlaying || playbackService.currentSong != nil {
                MiniPlayerView()
                    .padding(.bottom, 49) // Offset above tab bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: playbackService.currentSong != nil)
    }

    // MARK: - Tabs

    private var libraryTab: some View {
        NavigationStack {
            LibraryView()
                .navigationDestination(for: AppDestination.self) { destination in
                    DestinationView(destination: destination)
                }
        }
        .tabItem {
            Label("Library", systemImage: "music.note.list")
        }
        .tag(Tab.library)
    }

    private var generateTab: some View {
        NavigationStack {
            MoodSelectorView()
                .navigationDestination(for: AppDestination.self) { destination in
                    DestinationView(destination: destination)
                }
        }
        .tabItem {
            Label("Generate", systemImage: "wand.and.stars")
        }
        .tag(Tab.generate)
    }

    private var analyzeTab: some View {
        NavigationStack {
            AnalysisView()
                .navigationDestination(for: AppDestination.self) { destination in
                    DestinationView(destination: destination)
                }
        }
        .tabItem {
            Label("Analyze", systemImage: "waveform")
        }
        .tag(Tab.analyze)
    }

    private var profileTab: some View {
        NavigationStack {
            ProfileView()
                .navigationDestination(for: AppDestination.self) { destination in
                    DestinationView(destination: destination)
                }
        }
        .tabItem {
            Label("Profile", systemImage: "person.circle")
        }
        .tag(Tab.profile)
    }
}

// MARK: - Tab Enum

extension AppTabView {
    enum Tab: String {
        case library, generate, analyze, profile
    }
}
