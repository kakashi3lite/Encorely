import SwiftUI

public enum NoirPalette {
    public static let background    = Color(red: 0.04, green: 0.04, blue: 0.06)          // #0A0A0F
    public static let surfaceTint   = Color(red: 0.08, green: 0.08, blue: 0.12, opacity: 0.65)
    public static let onGlass       = Color.white.opacity(0.92)
    public static let subduedText   = Color.white.opacity(0.72)
    public static let strokeHi      = Color.white.opacity(0.35)
    public static let strokeLo      = Color.white.opacity(0.08)
    public static let highlight     = Color.white.opacity(0.08)
    public static let shadow        = Color.black.opacity(0.45)
    public static let accent        = Color(red: 0.40, green: 0.85, blue: 0.95)          // cyan pop for focus/active
}
