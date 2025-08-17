import SwiftUI

struct SafeAreaHandler: ViewModifier {
    @Environment(\.safeAreaInsets) private var safeAreaInsets

    func body(content: Content) -> some View {
        content
            .padding(.bottom, safeAreaInsets.bottom)
            .padding(.top, safeAreaInsets.top)
            .ignoresSafeArea(edges: .bottom)
    }
}

private struct SafeAreaInsetsKey: EnvironmentKey {
    static let defaultValue: EdgeInsets = .init(top: 0, leading: 0, bottom: 0, trailing: 0)
}

extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        get { self[SafeAreaInsetsKey.self] }
        set { self[SafeAreaInsetsKey.self] = newValue }
    }
}

extension View {
    func withSafeArea() -> some View {
        modifier(SafeAreaHandler())
    }
}
