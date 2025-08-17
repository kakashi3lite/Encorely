import SwiftUI

struct NavigationContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
            .navigationViewStyle(.stack)
        }
    }
}

struct NavigationBarModifier: ViewModifier {
    let title: String
    var backgroundColor: Color = .init(.systemBackground)
    var foregroundColor: Color = .primary

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(foregroundColor)
                }
            }
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

extension View {
    func navigationTitle(
        _ title: String,
        backgroundColor: Color = Color(.systemBackground),
        foregroundColor: Color = .primary
    ) -> some View {
        modifier(NavigationBarModifier(
            title: title,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor
        ))
    }
}
