//
//  PersonalityTypes.swift
//  Domain
//
//  Created by AI Assistant on 05/21/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation

/// Music personality types for the app
public enum PersonalityType: String, CaseIterable, Codable {
    case explorer = "Explorer"
    case curator = "Curator"
    case enthusiast = "Enthusiast"
    case social = "Social"
    case ambient = "Ambient"
    case analyzer = "Analyzer"
    
    /// Personality traits and behaviors
    public var traits: [PersonalityTrait] {
        switch self {
        case .explorer:
            return [
                PersonalityTrait(type: .explorer, value: 0.9),
                PersonalityTrait(type: .curator, value: 0.3),
                PersonalityTrait(type: .social, value: 0.6)
            ]
        case .curator:
            return [
                PersonalityTrait(type: .curator, value: 0.9),
                PersonalityTrait(type: .analyzer, value: 0.7),
                PersonalityTrait(type: .enthusiast, value: 0.5)
            ]
        case .enthusiast:
            return [
                PersonalityTrait(type: .enthusiast, value: 0.9),
                PersonalityTrait(type: .analyzer, value: 0.6),
                PersonalityTrait(type: .explorer, value: 0.4)
            ]
        case .social:
            return [
                PersonalityTrait(type: .social, value: 0.9),
                PersonalityTrait(type: .explorer, value: 0.5),
                PersonalityTrait(type: .enthusiast, value: 0.6)
            ]
        case .ambient:
            return [
                PersonalityTrait(type: .ambient, value: 0.9),
                PersonalityTrait(type: .curator, value: 0.4),
                PersonalityTrait(type: .analyzer, value: 0.2)
            ]
        case .analyzer:
            return [
                PersonalityTrait(type: .analyzer, value: 0.9),
                PersonalityTrait(type: .curator, value: 0.7),
                PersonalityTrait(type: .enthusiast, value: 0.8)
            ]
        }
    }
}

/// Individual personality trait with strength
public struct PersonalityTrait: Codable {
    public let type: PersonalityType
    public let value: Float // 0.0-1.0
    
    public init(type: PersonalityType, value: Float) {
        self.type = type
        self.value = value
    }
}
