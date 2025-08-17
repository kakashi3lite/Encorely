//
//  SupportingTypes.swift
//  AI-Mixtapes
//
//  Created by Claude AI on 05/30/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import AppKit
import Foundation

// MARK: - Supporting Types

public struct AppTheme {
    public let primaryColor: UIColor
    public let secondaryColor: UIColor
    public let backgroundColor: UIColor
    public let textColor: UIColor

    public init(primaryColor: UIColor, secondaryColor: UIColor, backgroundColor: UIColor, textColor: UIColor) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.backgroundColor = backgroundColor
        self.textColor = textColor
    }
}

public enum SheetType {
    case settings
    case moodSelector
    case personalitySelector
    case aiGenerator
    case siriShortcuts
}

public enum NotificationEvent {
    case moodDetected(Mood)
    case playlistGenerated(String)
    case analysisComplete
}

public struct PlaylistContext {
    public let mood: Mood
    public let activityType: String?
    public let timeOfDay: Int
    public let duration: TimeInterval

    public init(mood: Mood, activityType: String? = nil, timeOfDay: Int = 0, duration: TimeInterval = 3600) {
        self.mood = mood
        self.activityType = activityType
        self.timeOfDay = timeOfDay
        self.duration = duration
    }
}

public struct Playlist {
    public let title: String
    public let songs: [Song]
    public let mood: Mood
    public let duration: TimeInterval

    public init(title: String, songs: [Song], mood: Mood, duration: TimeInterval) {
        self.title = title
        self.songs = songs
        self.mood = mood
        self.duration = duration
    }
}

public struct MoodAction {
    public let title: String
    public let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
}

public struct PersonalityTrait {
    public let name: String
    public let score: Float

    public init(name: String, score: Float) {
        self.name = name
        self.score = score
    }
}
