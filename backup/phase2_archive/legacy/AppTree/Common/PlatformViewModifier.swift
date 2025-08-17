import SwiftUI

struct PlatformViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
            content
                .edgesIgnoringSafeArea(.bottom)
                .statusBar(hidden: false)
        #else
            content
        #endif
    }
}

extension View {
    func applyPlatformModifiers() -> some View {
        modifier(PlatformViewModifier())
    }
}
