import SwiftUI

// MARK: - Content Integration

struct IntegratedWireframeShowcase: View {
    @StateObject var wireframeManager: WireframeManager
    @State private var selectedTab = 0
    @State private var selectedWireframe: String?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    init(moodEngine: MoodEngine, personalityEngine: PersonalityEngine) {
        _wireframeManager = StateObject(wrappedValue: WireframeManager(
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                // Navigation tabs
                adaptiveTabBar
                    .wireframeThemed(wireframeManager)
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    navigationFlowSection
                        .tag(0)
                    
                    playerFlowSection
                        .tag(1)
                    
                    contentFlowSection
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .animation(.easeInOut, value: selectedTab)
        }
    }
    
    private var adaptiveTabBar: some View {
        let navigationStyle = wireframeManager.preferredNavigationStyle
        
        return Group {
            switch navigationStyle {
            case .hierarchical:
                VStack(alignment: .leading, spacing: 8) {
                    Text(tabTitle)
                        .font(.title.bold())
                    
                    HStack(spacing: 16) {
                        ForEach(0..<3) { index in
                            TabButton(title: tabTitles[index], isSelected: selectedTab == index) {
                                selectedTab = index
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
            case .tabbed:
                Picker("Section", selection: $selectedTab) {
                    ForEach(0..<3) { index in
                        Text(tabTitles[index]).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
            case .contextual:
                HStack {
                    ForEach(0..<3) { index in
                        Button(action: { selectedTab = index }) {
                            VStack(spacing: 4) {
                                Image(systemName: tabIcons[index])
                                    .font(.system(size: 22))
                                Text(tabTitles[index])
                                    .font(.caption)
                            }
                            .foregroundColor(selectedTab == index ? wireframeManager.dynamicColor(for: .primary) : .secondary)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var tabTitles: [String] {
        ["Navigation", "Player", "Content"]
    }
    
    private var tabIcons: [String] {
        ["rectangle.stack", "play.circle", "folder"]
    }
    
    private var tabTitle: String {
        switch selectedTab {
        case 0:
            return "Navigation Flow"
        case 1:
            return "Player Flow"
        case 2:
            return "Content Flow"
        default:
            return ""
        }
    }
}

// MARK: - Supporting Components

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct WireframeShowcase: View {
    @State private var selectedTab = 0
    @State private var selectedWireframe: String?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.extraLarge) {
                // Navigation tabs
                Picker("Section", selection: $selectedTab) {
                    Text("Navigation").tag(0)
                    Text("Player").tag(1)
                    Text("Content").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Section title
                Text(tabTitle)
                    .font(.system(size: horizontalSizeClass == .regular ? DesignSystem.FontSize.largeTitle : DesignSystem.FontSize.title, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case 0:
                        navigationFlowSection
                    case 1:
                        playerFlowSection
                    case 2:
                        contentFlowSection
                    default:
                        EmptyView()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
            .padding(.vertical, DesignSystem.Spacing.extraLarge)
        }
        .animation(.easeInOut(duration: AnimationConstants.defaultDuration), value: selectedTab)
    }
    
    // MARK: - Layout Sections
    
    private var navigationFlowSection: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.large) {
                    FocusableWireframePhone("Onboarding") {
                        OnboardingWireframe()
                    }
                    
                    FocusableWireframePhone("Home") {
                        HomeWireframe()
                    }
                    
                    FocusableWireframePhone("Mood") {
                        MoodSelectionWireframe()
                    }
                    
                    FocusableWireframePhone("Generate") {
                        MixtapeGenerationWireframe()
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var playerFlowSection: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.large) {
                    // Mini Player
                    WireframePhone {
                        WireframeContainer("Now Playing") {
                            MiniPlayerWireframe()
                        }
                    }
                    
                    // Full Player
                    WireframePhone {
                        WireframeContainer("Player") {
                            FullPlayerWireframe()
                        }
                    }
                    
                    // Queue
                    WireframePhone {
                        WireframeContainer("Queue") {
                            QueueWireframe()
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var contentFlowSection: some View {
        VStack(spacing: DesignSystem.Spacing.large) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.large) {
                    // Playlist Detail
                    WireframePhone {
                        WireframeContainer("Playlist") {
                            PlaylistDetailWireframe()
                        }
                    }
                    .onTapGesture {
                        withAnimation {
                            selectedWireframe = "playlist"
                        }
                    }
                    
                    // More wireframes can be added here...
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Focusable Wireframe Phone

struct FocusableWireframePhone<Content: View>: View {
    let title: String
    let content: Content
    @State private var isSelected = false
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        WireframeContainer(title) {
            content
                .frame(width: 350, height: 700)
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .shadow(color: isSelected ? DesignSystem.Shadow.large : DesignSystem.Shadow.medium, radius: isSelected ? 20 : 10)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            withAnimation {
                isSelected.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) wireframe")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to expand")
    }
}

// Wireframe Phone Container
struct WireframePhone<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        Mockup(type: .mobile) {
            content
                .frame(width: 350, height: 700)
                .background(Color(.systemBackground))
        }
        .frame(width: 350, height: 700)
    }
}

// MARK: - Individual Wireframe Views

struct OnboardingWireframe: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "music.note.list")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 16) {
                Text("Welcome to AI Mixtapes")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("Your smart music companion that adapts to your personality and mood")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                WireframeButton("Get Started", icon: "arrow.right")
                    
                WireframeButton("Sign in with Apple", icon: "apple.logo", style: .secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

struct HomeWireframe: View {
    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            WireframeNavigationBar(
                title: "Home",
                trailingItem: .init(icon: "person.crop.circle", action: {})
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // Current mood card
                    WireframeCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Current Mood")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("Energetic")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            Circle()
                                .fill(Color.yellow.opacity(0.2))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image(systemName: "bolt.fill")
                                        .foregroundColor(.yellow)
                                )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Recent mixtapes
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recent Mixtapes")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Text("See All")
                                    .font(.subheadline)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(0..<3) { i in
                                    VStack(alignment: .leading, spacing: 8) {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.secondary.opacity(0.1))
                                            .frame(width: 160, height: 160)
                                            .overlay(
                                                Image(systemName: "music.note")
                                                    .font(.system(size: 40))
                                                    .foregroundColor(.secondary)
                                            )
                                        
                                        Text("Mixtape \(i + 1)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text("\(Int.random(in: 8...15)) songs")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(width: 160)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Mood-based recommendations
                    VStack(alignment: .leading, spacing: 16) {
                        Text("For Your Mood")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        ForEach(0..<3) { i in
                            WireframeListItem(
                                title: "Recommended Mixtape \(i + 1)",
                                subtitle: "\(Int.random(in: 8...15)) songs",
                                leadingIcon: "music.note",
                                trailingIcon: "play.fill"
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            
            // Tab bar
            WireframeTabBar(
                items: [
                    ("house", "Home"),
                    ("waveform", "Library"),
                    ("plus.circle", "Create"),
                    ("heart", "For You")
                ],
                selectedIndex: 0
            )
        }
    }
}

struct MoodSelectionWireframe: View {
    private let moods: [(name: String, icon: String, color: Color)] = [
        ("Energetic", "bolt.fill", .yellow),
        ("Chill", "leaf.fill", .green),
        ("Focused", "brain.fill", .blue),
        ("Happy", "sun.max.fill", .orange),
        ("Melancholic", "cloud.rain.fill", .purple),
        ("Romantic", "heart.fill", .pink)
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("How are you feeling?")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("Select your current mood to get personalized mixtapes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top)
            
            // Mood grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2),
                spacing: 16
            ) {
                ForEach(moods, id: \.name) { mood in
                    Button(action: {}) {
                        VStack(spacing: 16) {
                            Circle()
                                .fill(mood.color.opacity(0.1))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: mood.icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(mood.color)
                                )
                            
                            Text(mood.name)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8)
                    }
                }
            }
            .padding()
            
            Spacer()
            
            // Continue button
            WireframeButton("Continue", icon: "arrow.right")
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }
}

struct MixtapeGenerationWireframe: View {
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Creating Your Mixtape")
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("AI is curating the perfect playlist for your mood")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)
            
            // Generation progress
            VStack(spacing: 32) {
                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("70%")
                            .font(.system(size: 24, weight: .bold))
                        Text("Complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status steps
                VStack(spacing: 24) {
                    ForEach(0..<4) { i in
                        HStack(spacing: 16) {
                            Image(systemName: i < 3 ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24))
                                .foregroundColor(i < 3 ? .green : .secondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text([
                                    "Analyzing your mood",
                                    "Finding matching songs",
                                    "Optimizing sequence",
                                    "Finalizing mixtape"
                                ][i])
                                .font(.system(size: 17))
                                
                                if i == 2 {
                                    Text("12 songs selected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Cancel button
            Button(action: {}) {
                Text("Cancel")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 32)
        }
    }
}

struct MiniPlayerWireframe: View {
    var body: some View {
        VStack {
            Spacer()
            
            // Mini player bar
            VStack(spacing: 0) {
                // Progress bar
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 200, height: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 16) {
                    // Album art
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        )
                    
                    // Song info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Song Title")
                            .font(.system(size: 16, weight: .medium))
                        Text("Artist Name")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Controls
                    HStack(spacing: 20) {
                        Button(action: {}) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
    }
}

struct FullPlayerWireframe: View {
    var body: some View {
        VStack(spacing: 32) {
            // Album art
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 280, height: 280)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 20)
            
            // Song info
            VStack(spacing: 8) {
                Text("Song Title")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Artist Name")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            VStack(spacing: 8) {
                // Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)
                        
                        // Progress
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * 0.4, height: 4)
                    }
                }
                .frame(height: 4)
                
                // Time labels
                HStack {
                    Text("2:15")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("-1:45")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Controls
            HStack(spacing: 40) {
                Button(action: {}) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 24))
                }
                
                Button(action: {}) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 64))
                }
                
                Button(action: {}) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 24))
                }
            }
            .foregroundColor(.primary)
            
            // Additional controls
            HStack(spacing: 48) {
                ForEach(["shuffle", "repeat", "list.bullet", "speaker.wave.2"], id: \.self) { icon in
                    Button(action: {}) {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.top, 48)
    }
}

struct QueueWireframe: View {
    var body: some View {
        VStack(spacing: 0) {
            // Header
            WireframeNavigationBar(
                title: "Up Next",
                leadingItem: .init(icon: "chevron.down", action: {})
            )
            
            // Queue list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<10) { i in
                        WireframeListItem(
                            title: "Song \(i + 1)",
                            subtitle: "Artist Name",
                            leadingIcon: i == 0 ? "music.note" : nil,
                            trailingIcon: "line.3.horizontal"
                        )
                        
                        if i < 9 {
                            WireframeDivider()
                        }
                    }
                }
                .padding(.vertical)
            }
        }
    }
}

struct ProfileWireframe: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Profile header
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                        )
                    
                    Text("User Name")
                        .font(.system(size: 24, weight: .bold))
                }
                
                // Stats
                HStack(spacing: 40) {
                    ForEach(["Mixtapes", "Following", "Followers"], id: \.self) { stat in
                        VStack(spacing: 4) {
                            Text("42")
                                .font(.system(size: 20, weight: .bold))
                            Text(stat)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Recent activity
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recent Activity")
                        .font(.system(size: 20, weight: .bold))
                    
                    ForEach(0..<4) { i in
                        WireframeListItem(
                            title: ["Created a new mixtape", "Liked a song", "Added to playlist", "Followed artist"][i],
                            subtitle: "\(Int.random(in: 1...24))h ago",
                            leadingIcon: ["plus.circle.fill", "heart.fill", "plus.square.fill", "person.fill"][i]
                        )
                    }
                }
            }
            .padding()
        }
    }
}

struct PersonalitySettingsWireframe: View {
    private let personalities = [
        ("Explorer", "Always discovering new music", "compass.fill"),
        ("Curator", "Creating perfect playlists", "star.fill"),
        ("Enthusiast", "Deep diving into genres", "heart.fill")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("Your Music Personality")
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    Text("Select the personality that best matches your music listening style")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Personality options
                VStack(spacing: 16) {
                    ForEach(personalities, id: \.0) { personality in
                        Button(action: {}) {
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.1))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Image(systemName: personality.2)
                                            .font(.system(size: 20))
                                            .foregroundColor(.accentColor)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(personality.0)
                                        .font(.system(size: 17, weight: .semibold))
                                    
                                    Text(personality.1)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Circle()
                                    .stroke(Color.accentColor, lineWidth: 2)
                                    .frame(width: 24, height: 24)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 8)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Save button
                WireframeButton("Save Changes")
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .padding(.vertical)
        }
    }
}

struct SettingsWireframe: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                ForEach([
                    (title: "Playback", items: ["Audio Quality", "Download Settings"]),
                    (title: "Notifications", items: ["Push Notifications", "Email Updates"]),
                    (title: "Privacy", items: ["Data Usage", "Connected Services"]),
                    (title: "Storage", items: ["Clear Cache", "Offline Content"]),
                    (title: "About", items: ["Version", "Legal"])
                ], id: \.title) { section in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(section.title)
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ForEach(section.items, id: \.self) { item in
                                WireframeListItem(
                                    title: item,
                                    subtitle: nil,
                                    leadingIcon: nil
                                )
                                
                                if item != section.items.last {
                                    WireframeDivider()
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Section Views

private var navigationFlowSection: some View {
    VStack(spacing: 30) {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 30) {
                // Onboarding
                WireframePhone {
                    WireframeContainer("Onboarding") {
                        OnboardingWireframe()
                    }
                }
                
                // Home
                WireframePhone {
                    WireframeContainer("Home") {
                        HomeWireframe()
                    }
                }
                
                // Mood Selection
                WireframePhone {
                    WireframeContainer("Mood") {
                        MoodSelectionWireframe()
                    }
                }
                
                // Mixtape Generation
                WireframePhone {
                    WireframeContainer("Generate") {
                        MixtapeGenerationWireframe()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private var playerFlowSection: some View {
    VStack(spacing: 30) {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 30) {
                // Mini Player
                WireframePhone {
                    WireframeContainer("Now Playing") {
                        MiniPlayerWireframe()
                    }
                }
                
                // Full Player
                WireframePhone {
                    WireframeContainer("Player") {
                        FullPlayerWireframe()
                    }
                }
                
                // Queue
                WireframePhone {
                    WireframeContainer("Queue") {
                        QueueWireframe()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private var profileFlowSection: some View {
    VStack(spacing: 30) {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 30) {
                // Profile
                WireframePhone {
                    WireframeContainer("Profile") {
                        ProfileWireframe()
                    }
                }
                
                // Personality Settings
                WireframePhone {
                    WireframeContainer("Personality") {
                        PersonalitySettingsWireframe()
                    }
                }
                
                // Settings
                WireframePhone {
                    WireframeContainer("Settings") {
                        SettingsWireframe()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
