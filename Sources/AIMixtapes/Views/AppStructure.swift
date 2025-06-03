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
        case .library: return "Library"
        case .generate: return "Generate"
        case .analyze: return "Analyze"
        case .insights: return "Insights" 
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .library: return "music.note.list"
        case .generate: return "wand.and.stars"
        case .analyze: return "waveform"
        case .insights: return "chart.bar"
        case .settings: return "gear"
        }
    }
}
