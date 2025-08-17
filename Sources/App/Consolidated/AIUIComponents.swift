//
//  AIUIComponents.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import SwiftUI

/// Banner that displays personalized messages from the AI
struct PersonalizedMessageBanner: View {
    @ObservedObject var aiService: AIIntegrationService
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main greeting
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(aiService.getPersonalizedGreeting())
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        if !isExpanded {
                            Text("Tap for more insights")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .imageScale(.medium)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }

            // Expanded insights section
            if isExpanded {
                // Divider with mood color
                Rectangle()
                    .fill(aiService.moodEngine.currentMood.color)
                    .frame(height: 1)
                    .padding(.vertical, 4)

                // AI insights
                Text(aiService.getUserInsights())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                // Actions based on current mood
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(aiService.moodEngine.getMoodBasedActions().prefix(3), id: \.action) { action in
                            MoodActionButton(action: action)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

/// Button displaying a mood-based action
struct MoodActionButton: View {
    let action: MoodAction

    var body: some View {
        Button(action: {
            // Handle action
        }) {
            HStack {
                Circle()
                    .fill(action.mood.color.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: action.mood.systemIcon)
                            .font(.system(size: 16))
                            .foregroundColor(action.mood.color))

                Text(action.title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(action.mood.color.opacity(0.5), lineWidth: 1))
        }
    }
}

/// Banner that displays AI insights about current music
struct AIInsightsView: View {
    @ObservedObject var aiService: AIIntegrationService
    @State private var insightText: String = "AI is analyzing your music preferences..."
    @State private var showTooltip: Bool = false

    // Simulated insights for demonstration
    private let insights = [
        "Your mixtapes suggest you enjoy upbeat music in the mornings",
        "We notice you frequently listen to ambient tracks while working",
        "Your musical taste spans several genres with focus on vocals",
        "You seem to prefer instrumental music in the evenings",
        "Your current mood matches well with your recent selections",
    ]

    var body: some View {
        Button(action: {
            // Cycle through insights
            let randomInsight = insights.randomElement() ?? "AI is analyzing your music tastes..."

            withAnimation {
                insightText = randomInsight
                showTooltip = true

                // Auto-hide tooltip after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showTooltip = false
                    }
                }
            }
        }) {
            HStack(spacing: 12) {
                // AI Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 32, height: 32)

                    Image(systemName: "brain")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }

                Text(insightText)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1))
            .overlay(
                Group {
                    if showTooltip {
                        VStack {
                            Text(
                                "AI analyzes your listening patterns to provide personalized insights and recommendations")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black.opacity(0.8)))
                                .offset(y: 40)
                                .transition(.opacity)
                        }
                    }
                })
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// View that displays when there are no mixtapes
struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: action) {
                Text("Create Mixtape")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }
}

/// Onboarding view shown on first launch
struct OnboardingView: View {
    @ObservedObject var personalityEngine: PersonalityEngine
    @Binding var isShowingOnboarding: Bool

    @State private var currentPage = 0
    @State private var selectedPersonality: PersonalityType?

    var body: some View {
        ZStack {
            // Background color gradients for different pages
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: backgroundColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                .edgesIgnoringSafeArea(.all)

            VStack {
                // Page content
                TabView(selection: $currentPage) {
                    // Welcome page
                    welcomeView
                        .tag(0)

                    // Personality selection page
                    personalitySelectionView
                        .tag(1)

                    // Features overview page
                    featuresView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))

                // Bottom button
                Button(action: {
                    if currentPage < 2 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        // Complete onboarding
                        if let personality = selectedPersonality {
                            personalityEngine.setPersonalityType(personality)
                        }
                        isShowingOnboarding = false
                    }
                }) {
                    Text(currentPage == 2 ? "Get Started" : "Continue")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.3)))
                        .padding(.horizontal, 40)
                }
                .disabled(currentPage == 1 && selectedPersonality == nil)
                .padding(.bottom, 40)
            }
            .foregroundColor(.white)
        }
    }

    // Background colors for each page
    var backgroundColors: [Color] {
        switch currentPage {
        case 0: [Color.purple, Color.blue]
        case 1: [Color.blue, Color.teal]
        case 2: [Color.teal, Color.green]
        default: [Color.blue, Color.purple]
        }
    }

    // Welcome page
    var welcomeView: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 80))
                .padding(.bottom, 20)

            Text("Welcome to AI Mixtapes")
                .font(.system(size: 28, weight: .bold))

            Text("Your smart music companion that adapts to your personality and mood")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // Personality selection page
    var personalitySelectionView: some View {
        VStack(spacing: 24) {
            Text("How do you enjoy music?")
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 40)

            Text("Select a personality that best matches your music listening style")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(PersonalityType.allCases, id: \.self) { personality in
                        Button(action: {
                            selectedPersonality = personality
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: personalityIcon(personality))
                                    .font(.system(size: 24))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(selectedPersonality == personality ?
                                                Color.white : Color.white.opacity(0.3)))
                                    .foregroundColor(selectedPersonality == personality ?
                                        personality.themeColor : .white)

                                VStack(alignment: .leading) {
                                    Text(personality.rawValue)
                                        .font(.headline)

                                    Text(personalityDescription(personality))
                                        .font(.subheadline)
                                        .lineLimit(2)
                                }

                                Spacer()

                                if selectedPersonality == personality {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(selectedPersonality == personality ? 0.3 : 0.1)))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // Features overview page
    var featuresView: some View {
        VStack(spacing: 40) {
            Text("Intelligent Features")
                .font(.system(size: 28, weight: .bold))
                .padding(.top, 40)

            VStack(spacing: 30) {
                featureRow(icon: "brain", title: "AI-Powered", description: "Adapts to your mood and personality")

                featureRow(
                    icon: "waveform.path.ecg",
                    title: "Mood Detection",
                    description: "Identifies the perfect music for your current mood"
                )

                featureRow(
                    icon: "person.fill.viewfinder",
                    title: "Personalization",
                    description: "Interface adapts to how you use the app"
                )

                featureRow(
                    icon: "rectangle.stack.person.crop",
                    title: "Smart Mixtapes",
                    description: "Create AI-generated mixtapes for any occasion"
                )
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    // Helper views
    func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.white.opacity(0.2)))

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
            }

            Spacer()
        }
    }

    // Helper functions
    func personalityIcon(_ type: PersonalityType) -> String {
        switch type {
        case .explorer: "safari"
        case .curator: "folder"
        case .enthusiast: "star"
        case .social: "person.2"
        case .ambient: "waveform"
        case .analyzer: "chart.bar"
        }
    }

    func personalityDescription(_ type: PersonalityType) -> String {
        switch type {
        case .explorer: "You enjoy discovering new music"
        case .curator: "You value organization and curation"
        case .enthusiast: "You dive deep into music you love"
        case .social: "You enjoy sharing music with others"
        case .ambient: "You prefer music in the background"
        case .analyzer: "You appreciate technical details"
        }
    }
}

// MARK: - Mixtape Generation Components

struct MoodCard: View {
    let mood: Mood
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Mood")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: mood.systemIcon)
                    .foregroundColor(mood.color)
            }

            Text(mood.rawValue)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: mood.color.opacity(0.2), radius: 10))
    }
}

struct PersonalityCard: View {
    let personality: PersonalityType
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Music Personality")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: personalityIcon)
                    .foregroundColor(themeColor)
            }

            Text(personality.rawValue)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: themeColor.opacity(0.2), radius: 10))
    }

    private var personalityIcon: String {
        switch personality {
        case .analyzer: "waveform.path"
        case .explorer: "safari"
        case .planner: "calendar"
        case .creative: "paintbrush"
        case .balanced: "circle.grid.2x2"
        }
    }

    private var themeColor: Color {
        switch personality {
        case .analyzer: .blue
        case .explorer: .purple
        case .planner: .orange
        case .creative: .pink
        case .balanced: .gray
        }
    }
}

struct ControlCard<Content: View>: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let content: Content

    init(
        title: String,
        value: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.headline)

            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground)))
    }
}

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Supporting Views

struct GenreSelectorView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedGenres: Set<String>

    private let genres = [
        "Pop", "Rock", "Hip-Hop", "R&B", "Jazz", "Classical",
        "Electronic", "Folk", "Country", "Metal", "Blues", "Latin",
    ]

    var body: some View {
        NavigationView {
            List(genres, id: \.self) { genre in
                Button(action: { toggleGenre(genre) }) {
                    HStack {
                        Text(genre)
                        Spacer()
                        if selectedGenres.contains(genre) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Genres")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }

    private func toggleGenre(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.remove(genre)
        } else {
            selectedGenres.insert(genre)
        }
    }
}

struct NameSuggestionsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var mixtapeName: String
    let mood: Mood
    let personality: Personality

    @State private var suggestions: [String] = []

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("AI Generated Names")) {
                    ForEach(suggestions, id: \.self) { name in
                        Button(action: { selectName(name) }) {
                            Text(name)
                        }
                    }
                }
            }
            .navigationTitle("Name Suggestions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                generateSuggestions()
            }
        }
    }

    private func selectName(_ name: String) {
        mixtapeName = name
        presentationMode.wrappedValue.dismiss()
    }

    private func generateSuggestions() {
        // In a real app, this would use AI to generate names based on mood and personality
        suggestions = [
            "\(mood.rawValue) Vibes",
            "\(personality.rawValue) Mix",
            "The \(mood.rawValue) Collection",
            "\(personality.rawValue) Journey",
            "Mood: \(mood.rawValue)",
            "\(mood.rawValue) \(personality.rawValue) Series",
        ]
    }
}

// MARK: - Accessibility Extensions

/// Extension to add accessibility features to UI components
extension View {
    /// Adds detailed accessibility labels and hints
    func accessibleMoodCard(mood: Mood, isSelected: Bool) -> some View {
        accessibilityLabel("Mood: \(mood.rawValue)")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityHint("Double tap to change mood")
            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    /// Adds accessibility for personality cards
    func accessiblePersonalityCard(personality: PersonalityType, isSelected: Bool) -> some View {
        accessibilityLabel("Personality: \(personality.rawValue)")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityHint("Double tap to change personality type")
            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    /// Adds accessibility for control cards
    func accessibleControlCard(label: String, value: String, iconName _: String) -> some View {
        accessibilityLabel("\(label): \(value)")
            .accessibilityHint("Double tap to adjust")
            .accessibilityAddTraits(.isButton)
    }

    /// Makes playlist items accessible
    func accessiblePlaylistItem(title: String, artist: String, isPlaying: Bool) -> some View {
        accessibilityLabel("\(title) by \(artist)")
            .accessibilityValue(isPlaying ? "Now playing" : "")
            .accessibilityHint("Double tap to play")
            .accessibilityAddTraits(isPlaying ? [.isSelected, .startsMediaSession] : .isButton)
    }

    /// Enhances generation progress accessibility
    func accessibleGenerationProgress(phase: String, progress: Double) -> some View {
        accessibilityLabel("Generating mixtape")
            .accessibilityValue("\(phase): \(Int(progress * 100))% complete")
            .accessibilityAddTraits(.updatesFrequently)
    }

    /// Enhances player controls accessibility
    func accessiblePlayerControls(isPlaying: Bool) -> some View {
        accessibilityLabel(isPlaying ? "Pause" : "Play")
            .accessibilityHint(isPlaying ? "Double tap to pause" : "Double tap to play")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Dynamic Type Support

/// Extension to add dynamic type support to text elements
extension Text {
    /// Makes text scalable with dynamic type settings while maintaining design
    func scalableText(style: Font.TextStyle, weight: Font.Weight = .regular) -> some View {
        font(.system(style))
            .fontWeight(weight)
            .lineLimit(nil) // Allow text to wrap as needed
            .fixedSize(horizontal: false, vertical: true) // Allow vertical growth
    }
}

// MARK: - High Contrast Support

/// Extension to add high contrast modes support
extension Color {
    /// Returns a color that works well in both regular and high contrast modes
    static func adaptiveColor(light: Color, dark: Color, highContrastLight: Color? = nil,
                              highContrastDark: Color? = nil) -> Color
    {
        Color(uiColor: UIColor { traitCollection in
            let isDarkMode = traitCollection.userInterfaceStyle == .dark
            let isHighContrast = traitCollection.accessibilityContrast == .high

            if isDarkMode {
                return isHighContrast && highContrastDark != nil
                    ? UIColor(highContrastDark!)
                    : UIColor(dark)
            } else {
                return isHighContrast && highContrastLight != nil
                    ? UIColor(highContrastLight!)
                    : UIColor(light)
            }
        })
    }
}

// MARK: - Accessible UI Components

/// Card that displays mood information with full accessibility support
struct AccessibleMoodCard: View {
    let mood: Mood
    let isSelected: Bool

    var body: some View {
        MoodCard(mood: mood, isSelected: isSelected)
            .accessibleMoodCard(mood: mood, isSelected: isSelected)
    }
}

/// Card that displays personality information with full accessibility support
struct AccessiblePersonalityCard: View {
    let personality: PersonalityType
    let isSelected: Bool

    var body: some View {
        PersonalityCard(personality: personality, isSelected: isSelected)
            .accessiblePersonalityCard(personality: personality, isSelected: isSelected)
    }
}

/// Progress indicator with enhanced accessibility
struct AccessibleProgressView: View {
    let title: String
    let subtitle: String
    let progress: Double
    let iconName: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 28))
                .foregroundColor(.accentColor)

            Text(title)
                .scalableText(style: .headline, weight: .semibold)

            Text(subtitle)
                .scalableText(style: .subheadline)
                .foregroundColor(.secondary)

            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(subtitle)")
        .accessibilityValue("\(Int(progress * 100))% complete")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Enhanced player controls with accessibility
struct AccessiblePlayerControls: View {
    let queuePlayer: AVQueuePlayer
    @Binding var isPlaying: Bool

    var body: some View {
        HStack(spacing: 24) {
            Button(action: {
                queuePlayer.seek(to: CMTime(
                    seconds: max(0, queuePlayer.currentTime().seconds - 15),
                    preferredTimescale: 600
                ))
            }) {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 24))
            }
            .accessibilityLabel("Rewind 15 seconds")

            Button(action: {
                if isPlaying {
                    queuePlayer.pause()
                } else {
                    queuePlayer.play()
                }
                isPlaying.toggle()
            }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
            }
            .accessiblePlayerControls(isPlaying: isPlaying)

            Button(action: {
                queuePlayer.seek(to: CMTime(seconds: queuePlayer.currentTime().seconds + 15, preferredTimescale: 600))
            }) {
                Image(systemName: "goforward.15")
                    .font(.system(size: 24))
            }
            .accessibilityLabel("Forward 15 seconds")
        }
    }
}
