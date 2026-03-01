import SwiftData
import SwiftUI

/// User profile tab showing personality, preferences, and account settings.
struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Environment(PersonalityEngine.self) private var personalityEngine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.musicKitService) private var musicKitService

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        List {
            personalitySection
            musicConnectionSection
            insightsLink
            aboutSection
        }
        .navigationTitle("Profile")
        .onAppear { ensureProfileExists() }
    }

    // MARK: - Personality

    private var personalitySection: some View {
        Section("Your Personality") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.fill.viewfinder")
                        .font(.title2)
                        .foregroundStyle(personalityEngine.currentPersonality.themeColor)

                    VStack(alignment: .leading) {
                        Text(personalityEngine.currentPersonality.rawValue)
                            .font(.headline)
                        Text(personalityEngine.currentPersonality.typeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if personalityEngine.confidence > 0 {
                    ProgressView(value: personalityEngine.confidence, total: 1.0)
                        .tint(personalityEngine.currentPersonality.themeColor)
                    Text("Confidence: \(Int(personalityEngine.confidence * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)

            PersonalityView()
        }
    }

    // MARK: - Music Connection

    private var musicConnectionSection: some View {
        Section("Apple Music") {
            HStack {
                Image(systemName: "music.note")
                Text(musicKitService.authorizationStatus == .authorized ? "Connected" : "Not Connected")
                Spacer()
                if musicKitService.authorizationStatus != .authorized {
                    Button("Connect") {
                        Task { await musicKitService.requestAuthorization() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }

    // MARK: - Insights

    private var insightsLink: some View {
        Section {
            NavigationLink(value: AppDestination.insights) {
                Label("Listening Insights", systemImage: "chart.bar.xaxis")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Build")
                Spacer()
                Text("1")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func ensureProfileExists() {
        guard profile == nil else { return }
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
    }
}
