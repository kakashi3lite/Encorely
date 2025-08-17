//
//  AccessibilityService.swift
//  Mixtapes
//
//  Comprehensive accessibility support for AI-Mixtapes
//  Fixes ISSUE-009: Accessibility Support
//

import Combine
import Foundation
import SwiftUI

/// Service providing comprehensive accessibility support throughout the app
class AccessibilityService: ObservableObject {
    // MARK: - Accessibility Settings

    @Published var isVoiceOverEnabled = false
    @Published var isReduceMotionEnabled = false
    @Published var preferredContentSizeCategory: ContentSizeCategory = .medium
    @Published var isHighContrastEnabled = false
    @Published var isBoldTextEnabled = false

    // MARK: - Announcement Management

    private let announcementQueue = DispatchQueue(label: "accessibility.announcements", qos: .userInteractive)
    private var pendingAnnouncements: [String] = []
    private var isAnnouncementInProgress = false

    // MARK: - Initialization

    init() {
        setupAccessibilityObservers()
        updateAccessibilitySettings()
    }

    // MARK: - Public Methods

    /// Make an accessibility announcement with queue management
    func announce(_ message: String, priority: AccessibilityAnnouncementPriority = .medium) {
        announcementQueue.async { [weak self] in
            guard let self else { return }

            if priority == .high {
                // High priority interrupts current announcement
                pendingAnnouncements.removeAll()
                makeImmediateAnnouncement(message)
            } else {
                // Queue regular announcements
                pendingAnnouncements.append(message)
                processAnnouncementQueue()
            }
        }
    }

    /// Get accessibility label for mood
    func accessibilityLabel(for mood: Mood) -> String {
        switch mood {
        case .energetic:
            "Energetic mood. High energy music with upbeat tempos for workouts and motivation."
        case .relaxed:
            "Relaxed mood. Calming melodies for unwinding and creating a peaceful atmosphere."
        case .happy:
            "Happy mood. Uplifting, cheerful music that enhances good moods."
        case .melancholic:
            "Melancholic mood. Reflective, emotional pieces for introspection."
        case .focused:
            "Focused mood. Music that helps maintain concentration and productivity."
        case .romantic:
            "Romantic mood. Intimate, emotional tracks that evoke feelings of love."
        case .angry:
            "Angry mood. Intense, powerful music for processing strong emotions."
        case .neutral:
            "Neutral mood. Balanced tracks that work well in various contexts."
        }
    }

    /// Get accessibility label for personality type
    func accessibilityLabel(for personality: PersonalityType) -> String {
        switch personality {
        case .explorer:
            "Explorer personality. You thrive on discovering new music and fresh experiences."
        case .curator:
            "Curator personality. You enjoy organizing and perfecting your music collections."
        case .enthusiast:
            "Enthusiast personality. You appreciate deep dives into artists and genres you love."
        case .social:
            "Social personality. You value music as a way to connect with others."
        case .ambient:
            "Ambient personality. You enjoy music as a backdrop to your daily activities."
        case .analyzer:
            "Analyzer personality. You appreciate the technical aspects and details of music."
        }
    }

    /// Get accessibility hint for actions
    func accessibilityHint(for action: AccessibilityAction) -> String {
        switch action {
        case .playMixtape:
            "Double tap to play this mixtape"
        case .createMixtape:
            "Double tap to create a new mixtape"
        case .editMood:
            "Double tap to change your current mood"
        case .openSettings:
            "Double tap to open settings"
        case .selectPersonality:
            "Double tap to select this personality type"
        case .addSong:
            "Double tap to add song to mixtape"
        case .removeSong:
            "Double tap to remove song from mixtape"
        case .reorderSongs:
            "Use rotor to reorder songs in the mixtape"
        case .analyzeSong:
            "Double tap to analyze audio features of this song"
        case .sharePlaylist:
            "Double tap to share this playlist"
        }
    }

    /// Get accessibility value for sliders and progress views
    func accessibilityValue(for element: AccessibilityElement, value: Float) -> String {
        switch element {
        case .moodConfidence:
            "\(Int(value * 100)) percent confidence"
        case .audioEnergy:
            "Energy level: \(Int(value * 100)) percent"
        case .audioValence:
            "Valence: \(Int(value * 100)) percent"
        case .playbackProgress:
            "Playback progress: \(Int(value * 100)) percent complete"
        case .volume:
            "Volume: \(Int(value * 100)) percent"
        case .mixingIntensity:
            "AI enhancement level: \(Int(value * 100)) percent"
        }
    }

    /// Generate accessible description for mixtape
    func accessibilityDescription(for mixtape: MixTape) -> String {
        var description = "Mixtape titled \(mixtape.wrappedTitle)"

        if mixtape.numberOfSongs > 0 {
            description += ", contains \(mixtape.numberOfSongs) songs"
        }

        if !mixtape.moodTagsArray.isEmpty {
            let moods = mixtape.moodTagsArray.joined(separator: ", ")
            description += ", moods: \(moods)"
        }

        if mixtape.playCount > 0 {
            description += ", played \(mixtape.playCount) times"
        }

        if mixtape.aiGenerated {
            description += ", AI generated"
        }

        return description
    }

    /// Generate accessible description for song
    func accessibilityDescription(for song: Song) -> String {
        var description = "Song: \(song.wrappedName)"

        if !song.wrappedArtist.isEmpty, song.wrappedArtist != "Unknown Artist" {
            description += " by \(song.wrappedArtist)"
        }

        if let moodTag = song.moodTag, let mood = Mood(rawValue: moodTag) {
            description += ", mood: \(mood.rawValue)"
        }

        if song.playCount > 0 {
            description += ", played \(song.playCount) times"
        }

        return description
    }

    // MARK: - Dynamic Type Support

    /// Get scaled font for dynamic type
    func scaledFont(_ style: Font.TextStyle, size: CGFloat? = nil) -> Font {
        if let size {
            return Font.custom("System", size: size, relativeTo: style)
        }
        return Font.system(style)
    }

    /// Check if large content size is being used
    var isUsingLargeContentSize: Bool {
        preferredContentSizeCategory >= .accessibilityMedium
    }

    // MARK: - High Contrast Support

    /// Get appropriate color for current accessibility settings
    func accessibleColor(primary: Color, highContrast: Color) -> Color {
        isHighContrastEnabled ? highContrast : primary
    }

    /// Get accessible background color
    func accessibleBackgroundColor() -> Color {
        isHighContrastEnabled ? .black : Color(.systemBackground)
    }

    /// Get accessible foreground color
    func accessibleForegroundColor() -> Color {
        isHighContrastEnabled ? .white : Color(.label)
    }

    // MARK: - Motion Preferences

    /// Check if motion should be reduced
    func shouldReduceMotion() -> Bool {
        isReduceMotionEnabled
    }

    /// Get appropriate animation for motion preferences
    func accessibleAnimation(_ animation: Animation, value _: some Equatable) -> Animation? {
        shouldReduceMotion() ? nil : animation
    }

    // MARK: - Screen Reader Support

    /// Check if screen reader is active
    func isScreenReaderActive() -> Bool {
        isVoiceOverEnabled
    }

    /// Get appropriate gesture instructions for screen reader users
    func screenReaderInstructions(for gesture: GestureType) -> String {
        switch gesture {
        case .swipe:
            "Swipe left or right to navigate between items"
        case .doubleTap:
            "Double tap to activate"
        case .dragAndDrop:
            "Use drag and drop to reorder items. Double tap and hold, then drag to new position"
        case .pinch:
            "Use pinch gesture to zoom"
        case .longPress:
            "Double tap and hold for more options"
        }
    }

    // MARK: - Private Methods

    private func setupAccessibilityObservers() {
        // Listen for accessibility changes
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAccessibilitySettings()
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAccessibilitySettings()
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.boldTextStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAccessibilitySettings()
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAccessibilitySettings()
        }

        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAccessibilitySettings()
        }
    }

    private func updateAccessibilitySettings() {
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled

        // Get current content size category
        let currentCategory = UIApplication.shared.preferredContentSizeCategory
        preferredContentSizeCategory = ContentSizeCategory(currentCategory)
    }

    private func makeImmediateAnnouncement(_ message: String) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    private func processAnnouncementQueue() {
        guard !isAnnouncementInProgress, !pendingAnnouncements.isEmpty else { return }

        isAnnouncementInProgress = true
        let message = pendingAnnouncements.removeFirst()

        DispatchQueue.main.async { [weak self] in
            UIAccessibility.post(notification: .announcement, argument: message)

            // Reset flag after delay to allow next announcement
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.isAnnouncementInProgress = false
                self?.processAnnouncementQueue()
            }
        }
    }
}

// MARK: - Supporting Types

enum AccessibilityAnnouncementPriority {
    case low, medium, high
}

enum AccessibilityAction {
    case playMixtape, createMixtape, editMood, openSettings
    case selectPersonality, addSong, removeSong, reorderSongs
    case analyzeSong, sharePlaylist
}

enum AccessibilityElement {
    case moodConfidence, audioEnergy, audioValence
    case playbackProgress, volume, mixingIntensity
}

enum GestureType {
    case swipe, doubleTap, dragAndDrop, pinch, longPress
}

// MARK: - SwiftUI Accessibility Extensions

extension View {
    /// Apply comprehensive accessibility support
    func accessibilitySupport(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        identifier: String? = nil,
        traits: AccessibilityTraits = [],
        service: AccessibilityService
    ) -> some View {
        accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityIdentifier(identifier ?? "")
            .accessibilityAddTraits(traits)
            .font(service.scaledFont(.body))
    }

    /// Apply accessibility colors based on high contrast settings
    func accessibilityColors(
        foreground: Color = .primary,
        background: Color = .clear,
        service: AccessibilityService
    ) -> some View {
        foregroundColor(service.accessibleColor(primary: foreground, highContrast: .white))
            .background(service.accessibleColor(primary: background, highContrast: .black))
    }

    /// Apply motion-sensitive animations
    func accessibilityAnimation(
        _ animation: Animation,
        value: some Equatable,
        service: AccessibilityService
    ) -> some View {
        self.animation(service.accessibleAnimation(animation, value: value), value: value)
    }

    /// Apply screen reader optimizations
    func screenReaderOptimized(service: AccessibilityService) -> some View {
        Group {
            if service.isScreenReaderActive() {
                self
                    .accessibilityElement(children: .combine)
            } else {
                self
            }
        }
    }
}

// MARK: - Accessibility View Modifiers

struct AccessibilityButtonStyle: ButtonStyle {
    let service: AccessibilityService

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? (service.shouldReduceMotion() ? 1.0 : 0.95) : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(
                service.accessibleAnimation(.easeInOut(duration: 0.1), value: configuration.isPressed),
                value: configuration.isPressed
            )
    }
}

struct AccessibilityCardStyle: ViewModifier {
    let service: AccessibilityService

    func body(content: Content) -> some View {
        content
            .padding()
            .background(service.accessibleBackgroundColor())
            .foregroundColor(service.accessibleForegroundColor())
            .cornerRadius(service.shouldReduceMotion() ? 8 : 12)
            .shadow(
                color: service.isHighContrastEnabled ? .clear : .black.opacity(0.1),
                radius: service.shouldReduceMotion() ? 1 : 3,
                x: 0,
                y: service.shouldReduceMotion() ? 1 : 2
            )
    }
}

// MARK: - Content Size Category Extension

extension ContentSizeCategory {
    init(_ uiContentSizeCategory: UIContentSizeCategory) {
        switch uiContentSizeCategory {
        case .extraSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .extraLarge: self = .extraLarge
        case .extraExtraLarge: self = .extraExtraLarge
        case .extraExtraExtraLarge: self = .extraExtraExtraLarge
        case .accessibilityMedium: self = .accessibilityMedium
        case .accessibilityLarge: self = .accessibilityLarge
        case .accessibilityExtraLarge: self = .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: self = .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: self = .accessibilityExtraExtraExtraLarge
        default: self = .medium
        }
    }
}
