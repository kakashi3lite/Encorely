// filepath: Sources/App/Consolidated/Intents/StartMixIntent.swift
import Foundation
import AppIntents

@available(iOS 16.0, *)
struct StartMixIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Mix"
    static var description = IntentDescription("Begin a mood-adaptive mixtape.")

    @Parameter(title: "Mood", default: "Neutral")
    var mood: String

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .init("StartMixIntent.perform"), object: mood)
        return .result()
    }
}

@available(iOS 16.0, *)
struct SetMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Mood"
    static var description = IntentDescription("Set the target mood or GEMS dimension.")

    @Parameter(title: "Mood", default: "Neutral")
    var mood: String

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .init("SetMoodIntent.perform"), object: mood)
        return .result()
    }
}

@available(iOS 16.0, *)
struct SwivelPodcastIntent: AppIntent {
    static var title: LocalizedStringResource = "Swivel Podcast"
    static var description = IntentDescription("Blend/transition music and podcast.")

    @Parameter(title: "Crossfade Seconds", default: 3.0)
    var crossfade: Double

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .init("SwivelPodcastIntent.perform"), object: crossfade)
        return .result()
    }
}

@available(iOS 16.0, *)
struct WhyThisSongIntent: AppIntent {
    static var title: LocalizedStringResource = "Why This Song"
    static var description = IntentDescription("Explain the current recommendation.")

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .init("WhyThisSongIntent.perform"), object: nil)
        return .result()
    }
}

@available(iOS 16.0, *)
struct EncorelyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(intent: StartMixIntent(),
                        phrases: ["Start a mix in \(.applicationName)", "Begin a mood mix in \(.applicationName)"]),
            AppShortcut(intent: SetMoodIntent(),
                        phrases: ["Set mood to \(.parameter(.mood)) in \(.applicationName)"]),
            AppShortcut(intent: SwivelPodcastIntent(),
                        phrases: ["Swivel podcast in \(.applicationName)"]),
            AppShortcut(intent: WhyThisSongIntent(),
                        phrases: ["Why this song in \(.applicationName)"])
        ]
    }
}
