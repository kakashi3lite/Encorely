import SwiftUI

enum NavigationItem: Hashable {
    case home
    case mixtapeDetail(MixTape)
    case moodSelector
    case personalitySetup
    case settings
    case audioAnalysis
    case insights
}

enum AppSection: Int, Hashable {
    case library = 0
    case generate = 1
    case analyze = 2
    case insights = 3
    case settings = 4

    var title: String {
        switch self {
        case .library: "Library"
        case .generate: "Generate"
        case .analyze: "Analyze"
        case .insights: "Insights"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .library: "music.note.list"
        case .generate: "wand.and.stars"
        case .analyze: "waveform"
        case .insights: "chart.bar"
        case .settings: "gear"
        }
    }
}
