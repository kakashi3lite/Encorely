//
//  MoodTypes.swift
//  Domain
//
//  Created by AI Assistant on 05/21/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation

/// Core mood enumeration for the app
public enum Mood: String, CaseIterable, Codable {
    case energetic = "Energetic"
    case relaxed = "Relaxed"
    case happy = "Happy"
    case melancholic = "Melancholic"
    case focused = "Focused"
    case romantic = "Romantic"
    case angry = "Angry"
    case neutral = "Neutral"
    
    /// System icon for the mood
    public var systemIcon: String {
        switch self {
        case .energetic: return "bolt.fill"
        case .relaxed: return "leaf.fill"
        case .happy: return "sun.max.fill"
        case .melancholic: return "cloud.rain.fill"
        case .focused: return "target"
        case .romantic: return "heart.fill"
        case .angry: return "flame.fill"
        case .neutral: return "circle.fill"
        }
    }
    
    /// Keywords associated with this mood for detection
    public var keywords: [String] {
        switch self {
        case .energetic: return ["energy", "power", "boost", "pump", "electric", "dynamic"]
        case .relaxed: return ["calm", "chill", "peaceful", "zen", "tranquil", "mellow"]
        case .happy: return ["joy", "cheerful", "bright", "positive", "upbeat", "sunny"]
        case .melancholic: return ["sad", "blue", "nostalgic", "wistful", "bittersweet", "moody"]
        case .focused: return ["concentrate", "study", "work", "productivity", "clarity", "flow"]
        case .romantic: return ["love", "intimate", "tender", "passionate", "sweet", "devotion"]
        case .angry: return ["rage", "intense", "fierce", "aggressive", "powerful", "raw"]
        case .neutral: return ["balanced", "steady", "normal", "everyday", "standard", "regular"]
        }
    }
}

/// Estimated mood from audio analysis
public enum EstimatedMood: String, CaseIterable, Codable {
    case energetic = "Energetic"
    case relaxed = "Relaxed"
    case happy = "Happy"
    case melancholic = "Melancholic"
    case focused = "Focused"
    case neutral = "Neutral"
    
    /// Convert to main Mood enum
    public var asMood: Mood {
        switch self {
        case .energetic: return .energetic
        case .relaxed: return .relaxed
        case .happy: return .happy
        case .melancholic: return .melancholic
        case .focused: return .focused
        case .neutral: return .neutral
        }
    }
}

/// Time of day context for mood analysis
public enum TimeOfDay: String, CaseIterable, Codable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"
    
    /// Current time of day
    public static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
}

/// Contextual information for sensor data
public struct ContextualInfo: Codable {
    public let timeOfDay: TimeOfDay
    public let dayOfWeek: Int // 1 = Sunday, 7 = Saturday
    public let location: LocationContext?
    public let weather: WeatherContext?
    
    public init(
        timeOfDay: TimeOfDay = .current,
        dayOfWeek: Int = Calendar.current.component(.weekday, from: Date()),
        location: LocationContext? = nil,
        weather: WeatherContext? = nil
    ) {
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek
        self.location = location
        self.weather = weather
    }
}

/// Location context (privacy-conscious)
public enum LocationContext: String, Codable, CaseIterable {
    case home, work, commute, gym, outdoors, unknown
}

/// Weather context for mood correlation
public struct WeatherContext: Codable {
    public let condition: WeatherCondition
    public let temperature: Float? // Celsius
    public let humidity: Float?    // 0.0-1.0
    
    public init(condition: WeatherCondition, temperature: Float? = nil, humidity: Float? = nil) {
        self.condition = condition
        self.temperature = temperature
        self.humidity = humidity
    }
}

/// Weather conditions that might affect mood
public enum WeatherCondition: String, Codable, CaseIterable {
    case sunny, cloudy, rainy, snowy, stormy, foggy, unknown
    
    /// Mood bias for this weather condition
    public var moodBias: [Mood: Float] {
        switch self {
        case .sunny: return [.happy: 0.3, .energetic: 0.2]
        case .rainy: return [.melancholic: 0.2, .relaxed: 0.1]
        case .stormy: return [.angry: 0.1, .energetic: 0.1]
        case .cloudy, .foggy: return [.neutral: 0.1]
        case .snowy: return [.relaxed: 0.2, .romantic: 0.1]
        case .unknown: return [:]
        }
    }
}
