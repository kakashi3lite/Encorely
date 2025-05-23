import SwiftUI

struct ScalableTextModifier: ViewModifier {
    let style: Font.TextStyle
    let weight: Font.Weight
    let maxSize: CGFloat?
    
    init(style: Font.TextStyle, weight: Font.Weight = .regular, maxSize: CGFloat? = nil) {
        self.style = style
        self.weight = weight
        self.maxSize = maxSize
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(style))
            .fontWeight(weight)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.5)
            .if(maxSize != nil) { view in
                view.modifier(MaxFontSizeModifier(maxSize: maxSize!))
            }
    }
}

struct MaxFontSizeModifier: ViewModifier {
    let maxSize: CGFloat
    
    func body(content: Content) -> some View {
        content.transformEffect(.init(scaleX: min(1, maxSize/UIFont.preferredFont(forTextStyle: .body).pointSize), y: min(1, maxSize/UIFont.preferredFont(forTextStyle: .body).pointSize)))
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    func scalableText(style: Font.TextStyle, weight: Font.Weight = .regular, maxSize: CGFloat? = nil) -> some View {
        modifier(ScalableTextModifier(style: style, weight: weight, maxSize: maxSize))
    }
}
