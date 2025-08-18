import Combine
import SwiftUI

enum Tab: CaseIterable {
    case playlists
    case podcasts
    case mixer
}

class SwipeNavigatorViewModel: ObservableObject {
    @Published var currentTab: Tab = .playlists

    private let tabs = Tab.allCases

    func swipeRight() {
        guard let currentIndex = tabs.firstIndex(of: currentTab) else { return }
        let nextIndex = (currentIndex + 1) % tabs.count
        currentTab = tabs[nextIndex]
    }

    func swipeLeft() {
        guard let currentIndex = tabs.firstIndex(of: currentTab) else { return }
        let previousIndex = currentIndex == 0 ? tabs.count - 1 : currentIndex - 1
        currentTab = tabs[previousIndex]
    }
}
