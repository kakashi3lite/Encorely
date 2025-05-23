import SwiftUI

struct AccessibleTouchTargetModifier: ViewModifier {
    let minSize: CGFloat
    
    init(minSize: CGFloat = 44) { // 44pt is Apple's recommended minimum
        self.minSize = minSize
    }
    
    func body(content: Content) -> some View {
        content
            .frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle()) // Makes entire frame tappable
    }
}

extension View {
    func accessibleTouchTarget(minSize: CGFloat = 44) -> some View {
        modifier(AccessibleTouchTargetModifier(minSize: minSize))
    }
}
