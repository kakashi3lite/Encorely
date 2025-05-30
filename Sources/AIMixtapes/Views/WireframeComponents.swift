import SwiftUI
import Combine

// MARK: - Design System Constants

private enum DesignSystem {
    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }
    
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 32
    }
    
    enum Shadow {
        static let small = Color.black.opacity(0.05)
        static let medium = Color.black.opacity(0.1)
        static let large = Color.black.opacity(0.15)
    }
    
    enum FontSize {
        static let caption: CGFloat = 12
        static let subheadline: CGFloat = 14
        static let body: CGFloat = 16
        static let headline: CGFloat = 17
        static let title: CGFloat = 24
        static let largeTitle: CGFloat = 28
    }
}

// MARK: - Base Components

struct WireframeContainer<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(title)
                .font(.system(size: DesignSystem.FontSize.headline, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(DesignSystem.Spacing.medium)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color(.separator)),
                    alignment: .bottom
                )
                .accessibilityAddTraits(.isHeader)
            
            // Content
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct MockupFrame<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color(.separator), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 20)
    }
}

// MARK: - Common Elements

struct WireframeButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary
        case secondary
        case ghost
    }
    
    init(_ title: String, icon: String? = nil, style: ButtonStyle = .primary) {
        self.title = title
        self.icon = icon
        self.style = style
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.FontSize.body, weight: .medium))
                    .accessibility(hidden: true)
            }
            
            Text(title)
                .font(.system(size: DesignSystem.FontSize.body, weight: .semibold))
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .frame(maxWidth: style == .ghost ? .infinity : nil)
        .background(
            Group {
                switch style {
                case .primary:
                    Color.accentColor
                case .secondary:
                    Color(.systemBackground)
                case .ghost:
                    Color.clear
                }
            }
        )
        .foregroundColor(style == .primary ? .white : .primary)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .stroke(style == .secondary ? Color(.separator) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(DesignSystem.CornerRadius.small)
        .shadow(
            color: style == .primary ? DesignSystem.Shadow.medium : .clear,
            radius: 4,
            x: 0,
            y: 2
        )
        .accessibilityElement(children: .combine)
    }
}

struct WireframeCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8)
    }
}

struct WireframeListItem: View {
    let title: String
    let subtitle: String?
    let leadingIcon: String?
    let trailingIcon: String?
    
    init(
        title: String,
        subtitle: String? = nil,
        leadingIcon: String? = nil,
        trailingIcon: String? = "chevron.right"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.medium) {
            if let icon = leadingIcon {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.FontSize.headline))
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                    .accessibility(hidden: true)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                Text(title)
                    .font(.system(size: DesignSystem.FontSize.body))
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: DesignSystem.FontSize.subheadline))
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title)\(subtitle != nil ? ", \(subtitle!)" : "")")
            
            Spacer()
            
            if let icon = trailingIcon {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.FontSize.subheadline))
                    .foregroundColor(.secondary)
                    .accessibility(hidden: true)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .background(Color(.systemBackground))
    }
}

struct WireframeDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 0.5)
    }
}

// MARK: - Navigation Elements

struct WireframeNavigationBar: View {
    let title: String
    let leadingItem: NavigationItem?
    let trailingItem: NavigationItem?
    
    struct NavigationItem {
        let icon: String
        let action: () -> Void
    }
    
    init(
        title: String,
        leadingItem: NavigationItem? = nil,
        trailingItem: NavigationItem? = nil
    ) {
        self.title = title
        self.leadingItem = leadingItem
        self.trailingItem = trailingItem
    }
    
    var body: some View {
        HStack {
            if let item = leadingItem {
                Button(action: item.action) {
                    Image(systemName: item.icon)
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            Text(title)
                .font(.system(size: 17, weight: .semibold))
            
            Spacer()
            
            if let item = trailingItem {
                Button(action: item.action) {
                    Image(systemName: item.icon)
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                }
            } else {
                Color.clear
                    .frame(width: 18)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct WireframeTabBar: View {
    let items: [(icon: String, title: String)]
    let selectedIndex: Int
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { index in
                VStack(spacing: 4) {
                    Image(systemName: items[index].icon + (selectedIndex == index ? ".fill" : ""))
                        .font(.system(size: 22))
                    
                    Text(items[index].title)
                        .font(.system(size: 10))
                }
                .foregroundColor(selectedIndex == index ? .accentColor : .secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }
}

// MARK: - Animation Constants

private enum AnimationConstants {
    static let defaultDuration: Double = 0.3
    static let springResponse: Double = 0.35
    static let springDampingFraction: Double = 0.7
    
    enum Scale {
        static let pressed: CGFloat = 0.98
        static let normal: CGFloat = 1.0
    }
    
    enum Opacity {
        static let dimmed: Double = 0.6
        static let normal: Double = 1.0
    }
}

// MARK: - Animation Modifiers

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AnimationConstants.Scale.pressed : AnimationConstants.Scale.normal)
            .opacity(configuration.isPressed ? AnimationConstants.Opacity.dimmed : AnimationConstants.Opacity.normal)
            .animation(.spring(
                response: AnimationConstants.springResponse,
                dampingFraction: AnimationConstants.springDampingFraction
            ), value: configuration.isPressed)
    }
}

struct TransitionModifier: ViewModifier {
    let edge: Edge
    
    func body(content: Content) -> some View {
        content
            .transition(
                .asymmetric(
                    insertion: .move(edge: edge).combined(with: .opacity),
                    removal: .opacity
                )
            )
    }
}

// MARK: - Wireframe Integration

/// Manages coordination between wireframes and core engines
final class WireframeManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var currentColorScheme: ColorScheme = .light
    @Published private(set) var currentTheme: Asset.PersonalityColor
    @Published private(set) var currentMood: Asset.MoodColor
    @Published private(set) var currentAudioFeatures: AudioFeatures = .neutral
    
    // MARK: - Private Properties
    private let moodEngine: MoodEngine
    private let personalityEngine: PersonalityEngine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(moodEngine: MoodEngine, personalityEngine: PersonalityEngine) {
        self.moodEngine = moodEngine
        self.personalityEngine = personalityEngine
        self.currentTheme = personalityEngine.currentPersonality
        self.currentMood = moodEngine.currentMood
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Sync with mood changes
        moodEngine.$currentMood
            .sink { [weak self] newMood in
                withAnimation(.easeInOut(duration: AnimationConstants.defaultDuration)) {
                    self?.currentMood = newMood
                    self?.updateAudioFeatures()
                }
            }
            .store(in: &cancellables)
        
        // Sync with personality changes
        personalityEngine.$currentPersonality
            .sink { [weak self] newPersonality in
                withAnimation(.easeInOut(duration: AnimationConstants.defaultDuration)) {
                    self?.currentTheme = newPersonality
                    self?.updateAudioFeatures()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Theme Helpers
    
    var uiPreferences: UIPreferences {
        currentTheme.uiPreferences
    }
    
    var preferredListStyle: UIPreferences.ListStyle {
        uiPreferences.listStyle
    }
    
    var preferredNavigationStyle: UIPreferences.NavigationStyle {
        uiPreferences.navigationStyle
    }
    
    // MARK: - Interaction Preferences
    
    var interactionPreferences: InteractionPreferences {
        currentTheme.interactionPreferences
    }
    
    // MARK: - Color Computation
    
    /// Computes dynamic colors based on current mood and audio features
    func dynamicColor(for component: WireframeComponent) -> Color {
        switch component {
        case .primary:
            return modifyColorByAudioFeatures(currentTheme.themeColor)
        case .secondary:
            return modifyColorByAudioFeatures(currentMood.color)
        case .accent:
            return Color.accentColor
        }
    }
    
    // MARK: - Audio Features Integration
    
    private func updateAudioFeatures() {
        currentAudioFeatures = AudioFeatures.forMood(currentMood)
    }
    
    /// Modifies colors based on audio features for dynamic visual effects
    private func modifyColorByAudioFeatures(_ baseColor: Color) -> Color {
        let features = currentAudioFeatures
        
        // Adjust brightness based on energy
        let brightness = features.energy 
        
        // Adjust saturation based on intensity
        let saturation = features.intensity 
        
        return baseColor
            .opacity(max(0.4, min(1.0, Double(features.energy))))
            .saturated(by: Double(saturation))
            .brightened(by: Double(brightness))
    }
}

// MARK: - Supporting Types

enum WireframeComponent {
    case primary
    case secondary
    case accent
}

// MARK: - View Modifiers

struct WireframeThemeModifier: ViewModifier {
    @ObservedObject var wireframeManager: WireframeManager
    let component: WireframeComponent
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(wireframeManager.dynamicColor(for: component))
            .animation(.easeInOut, value: wireframeManager.currentTheme)
            .animation(.easeInOut, value: wireframeManager.currentMood)
    }
}

// MARK: - View Extensions

extension View {
    func wireframeThemed(_ manager: WireframeManager, as component: WireframeComponent = .primary) -> some View {
        modifier(WireframeThemeModifier(wireframeManager: manager, component: component))
    }
}

// MARK: - Enhanced Base Components

struct EnhancedWireframeContainer<Content: View>: View {
    let title: String
    let content: Content
    @ObservedObject var wireframeManager: WireframeManager
    
    init(_ title: String, wireframeManager: WireframeManager, @ViewBuilder content: () -> Content) {
        self.title = title
        self.wireframeManager = wireframeManager
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Adaptive Header
            title.map { title in
                switch wireframeManager.preferredNavigationStyle {
                case .hierarchical:
                    Text(title)
                        .font(.system(size: DesignSystem.FontSize.headline, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemBackground))
                        .overlay(
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(Color(.separator)),
                            alignment: .bottom
                        )
                    
                case .tabbed:
                    Text(title)
                        .font(.system(size: DesignSystem.FontSize.headline, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(Color(.systemBackground))
                        .overlay(
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(Color(.separator)),
                            alignment: .bottom
                        )
                    
                case .contextual:
                    HStack {
                        Text(title)
                            .font(.system(size: DesignSystem.FontSize.headline, weight: .semibold))
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: DesignSystem.FontSize.body))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .overlay(
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundColor(Color(.separator)),
                        alignment: .bottom
                    )
                }
            }
            
            // Content with list style adaptation
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.listStyle, wireframeManager.preferredListStyle)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - List Style Environment Key

struct ListStyleKey: EnvironmentKey {
    static let defaultValue: UIPreferences.ListStyle = .list
}

extension EnvironmentValues {
    var listStyle: UIPreferences.List.Style {
        get { self[ListStyleKey.self] }
        set { self[ListStyleKey.self] = newValue }
    }
}

// MARK: - Enhanced Button Components

struct EnhancedWireframeButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    @ObservedObject var wireframeManager: WireframeManager
    let action: () -> Void
    
    enum ButtonStyle {
        case primary
        case secondary
        case ghost
    }
    
    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        wireframeManager: WireframeManager,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.wireframeManager = wireframeManager
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.small) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: DesignSystem.FontSize.body, weight: .medium))
                        .accessibility(hidden: true)
                }
                
                Text(title)
                    .font(.system(size: DesignSystem.FontSize.body, weight: .semibold))
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .padding(.vertical, DesignSystem.Spacing.small)
            .frame(maxWidth: style == .ghost ? .infinity : nil)
            .background(buttonBackground)
            .foregroundColor(buttonForeground)
            .overlay(buttonBorder)
            .cornerRadius(DesignSystem.CornerRadius.small)
            .shadow(color: buttonShadow, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
    }
    
    private var buttonBackground: Color {
        switch style {
        case .primary:
            return wireframeManager.dynamicColor(for: .primary)
        case .secondary:
            return Color(.systemBackground)
        case .ghost:
            return Color.clear
        }
    }
    
    private var buttonForeground: Color {
        style == .primary ? .white : wireframeManager.dynamicColor(for: .primary)
    }
    
    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
            .stroke(style == .secondary ? Color(.separator) : Color.clear, lineWidth: 1)
    }
    
    private var buttonShadow: Color {
        style == .primary ? DesignSystem.Shadow.medium : .clear
    }
}

// MARK: - Animation Constants

private enum AnimationConstants {
    static let defaultDuration: Double = 0.3
    static let springResponse: Double = 0.35
    static let springDampingFraction: Double = 0.7
    
    enum Scale {
        static let pressed: CGFloat = 0.98
        static let normal: CGFloat = 1.0
    }
    
    enum Opacity {
        static let dimmed: Double = 0.6
        static let normal: Double = 1.0
    }
}

// MARK: - Animation Modifiers

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AnimationConstants.Scale.pressed : AnimationConstants.Scale.normal)
            .opacity(configuration.isPressed ? AnimationConstants.Opacity.dimmed : AnimationConstants.Opacity.normal)
            .animation(.spring(
                response: AnimationConstants.springResponse,
                dampingFraction: AnimationConstants.springDampingFraction
            ), value: configuration.isPressed)
    }
}

struct TransitionModifier: ViewModifier {
    let edge: Edge
    
    func body(content: Content) -> some View {
        content
            .transition(
                .asymmetric(
                    insertion: .move(edge: edge).combined(with: .opacity),
                    removal: .opacity
                )
            )
    }
}

// MARK: - Wireframe Integration

/// Manages coordination between wireframes and core engines
final class WireframeManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var currentColorScheme: ColorScheme = .light
    @Published private(set) var currentTheme: Asset.PersonalityColor
    @Published private(set) var currentMood: Asset.MoodColor
    @Published private(set) var currentAudioFeatures: AudioFeatures = .neutral
    
    // MARK: - Private Properties
    private let moodEngine: MoodEngine
    private let personalityEngine: PersonalityEngine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(moodEngine: MoodEngine, personalityEngine: PersonalityEngine) {
        self.moodEngine = moodEngine
        self.personalityEngine = personalityEngine
        self.currentTheme = personalityEngine.currentPersonality
        self.currentMood = moodEngine.currentMood
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Sync with mood changes
        moodEngine.$currentMood
            .sink { [weak self] newMood in
                withAnimation(.easeInOut(duration: AnimationConstants.defaultDuration)) {
                    self?.currentMood = newMood
                    self?.updateAudioFeatures()
                }
            }
            .store(in: &cancellables)
        
        // Sync with personality changes
        personalityEngine.$currentPersonality
            .sink { [weak self] newPersonality in
                withAnimation(.easeInOut(duration: AnimationConstants.defaultDuration)) {
                    self?.currentTheme = newPersonality
                    self?.updateAudioFeatures()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Theme Helpers
    
    var uiPreferences: UIPreferences {
        currentTheme.uiPreferences
    }
    
    var preferredListStyle: UIPreferences.List.Style {
        uiPreferences.listStyle
    }
    
    var preferredNavigationStyle: UIPreferences.NavigationStyle {
        uiPreferences.navigationStyle
    }
    
    // MARK: - Interaction Preferences
    
    var interactionPreferences: InteractionPreferences {
        currentTheme.interactionPreferences
    }
    
    // MARK: - Color Computation
    
    /// Computes dynamic colors based on current mood and audio features
    func dynamicColor(for component: WireframeComponent) -> Color {
        switch component {
        case .primary:
            return modifyColorByAudioFeatures(currentTheme.themeColor)
        case .secondary:
            return modifyColorByAudioFeatures(currentMood.color)
        case .accent:
            return Color.accentColor
        }
    }
    
    // MARK: - Audio Features Integration
    
    private func updateAudioFeatures() {
        currentAudioFeatures = AudioFeatures.forMood(currentMood)
    }
    
    /// Modifies colors based on audio features for dynamic visual effects
    private func modifyColorByAudioFeatures(_ baseColor: Color) -> Color {
        let features = currentAudioFeatures
        
        // Adjust brightness based on energy
        let brightness = features.energy 
        
        // Adjust saturation based on intensity
        let saturation = features.intensity 
        
        return baseColor
            .opacity(max(0.4, min(1.0, Double(features.energy))))
            .saturated(by: Double(saturation))
            .brightened(by: Double(brightness))
    }
}

// MARK: - Supporting Types

enum WireframeComponent {
    case primary
    case secondary
    case accent
}

// MARK: - View Modifiers

struct WireframeThemeModifier: ViewModifier {
    @ObservedObject var wireframeManager: WireframeManager
    let component: WireframeComponent
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(wireframeManager.dynamicColor(for: component))
            .animation(.easeInOut, value: wireframeManager.currentTheme)
            .animation(.easeInOut, value: wireframeManager.currentMood)
    }
}

// MARK: - View Extensions

extension View {
    func wireframeThemed(_ manager: WireframeManager, as component: WireframeComponent = .primary) -> some View {
        modifier(WireframeThemeModifier(wireframeManager: manager, component: component))
    }
}

// MARK: - Content Wireframes

struct PlaylistDetailWireframe: View {
    private let playlistName: String
    private let songCount: Int
    private let duration: String
    @State private var selectedSortOption = "Title"
    @State private var isEditing = false
    
    init(
        playlistName: String = "My Playlist",
        songCount: Int = 24,
        duration: String = "1h 42m"
    ) {
        self.playlistName = playlistName 
        self.songCount = songCount
        self.duration = duration
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header section
            ZStack {
                // Cover art
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                    )
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.4),
                        Color.black.opacity(0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
                
                // Navigation bar
                VStack {
                    HStack {
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: DesignSystem.FontSize.headline))
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel("Back")
                        
                        Spacer()
                        
                        Button(action: { isEditing.toggle() }) {
                            Text(isEditing ? "Done" : "Edit")
                                .font(.system(size: DesignSystem.FontSize.body))
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel(isEditing ? "Finish editing" : "Edit playlist")
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Playlist info
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.small) {
                        Text(playlistName)
                            .font(.system(size: DesignSystem.FontSize.title, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("\(songCount) songs • \(duration)")
                            .font(.system(size: DesignSystem.FontSize.subheadline))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
            
            // Controls
            HStack(spacing: DesignSystem.Spacing.large) {
                Button(action: {}) {
                    VStack(spacing: DesignSystem.Spacing.small) {
                        Image(systemName: "play.fill")
                            .font(.system(size: DesignSystem.FontSize.title))
                        Text("Play")
                            .font(.system(size: DesignSystem.FontSize.caption))
                    }
                }
                .accessibilityLabel("Play all songs")
                
                Button(action: {}) {
                    VStack(spacing: DesignSystem.Spacing.small) {
                        Image(systemName: "shuffle")
                            .font(.system(size: DesignSystem.FontSize.title))
                        Text("Shuffle")
                            .font(.system(size: DesignSystem.FontSize.caption))
                    }
                }
                .accessibilityLabel("Shuffle playlist")
                
                Button(action: {}) {
                    VStack(spacing: DesignSystem.Spacing.small) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: DesignSystem.FontSize.title))
                        Text("Enhance")
                            .font(.system(size: DesignSystem.FontSize.caption))
                    }
                }
                .accessibilityLabel("Enhance playlist with AI")
            }
            .foregroundColor(.accentColor)
            .padding()
            
            // Sort options
            if isEditing {
                Picker("Sort by", selection: $selectedSortOption) {
                    Text("Title").tag("Title")
                    Text("Artist").tag("Artist")
                    Text("Recently Added").tag("Recent")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Song list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<songCount) { i in
                        WireframeListItem(
                            title: "Song \(i + 1)",
                            subtitle: "Artist Name",
                            leadingIcon: nil,
                            trailingIcon: isEditing ? "line.3.horizontal" : "ellipsis"
                        )
                        
                        if i < songCount - 1 {
                            WireframeDivider()
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .animation(.easeInOut(duration: AnimationConstants.defaultDuration), value: isEditing)
    }
}
