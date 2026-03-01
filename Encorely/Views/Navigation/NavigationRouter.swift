import SwiftUI

/// Typed destinations for NavigationStack routing.
/// Each case maps to a detail view pushed onto the stack.
enum AppDestination: Hashable {
    case mixtapeDetail(mixtapeID: String)
    case songDetail(songID: String)
    case moodSelector
    case generatorResult(mood: Mood)
    case profile
    case insights
}

/// Resolves AppDestination values to their corresponding views.
struct DestinationView: View {
    let destination: AppDestination

    var body: some View {
        switch destination {
        case .mixtapeDetail(let id):
            MixtapeDetailView(mixtapeID: id)
        case .songDetail(let id):
            Text("Song \(id)")
        case .moodSelector:
            MoodSelectorView()
        case .generatorResult(let mood):
            GeneratorView(targetMood: mood)
        case .profile:
            ProfileView()
        case .insights:
            InsightsView.asDestination()
        }
    }
}
