import Foundation
import SwiftUI
import CoreML
import AVFoundation

// MARK: - Module Configuration
public struct AIMixtapesConfig {
    /// Logging configuration
    public var enableLogging: Bool = true
    /// Memory management configuration
    public var maxBufferSize: Int = 4096
    /// Audio processing configuration
    public var sampleRate: Double = 44100
    
    public init(
        enableLogging: Bool = true,
        maxBufferSize: Int = 4096,
        sampleRate: Double = 44100
    ) {
        self.enableLogging = enableLogging
        self.maxBufferSize = maxBufferSize
        self.sampleRate = sampleRate
    }
}

/// AI-powered music playlist generation and analysis framework.
///
/// The AIMixtapes framework provides tools for creating intelligent music playlists
/// based on mood detection, personality analysis, and audio processing.
///
/// ## Overview
///
/// AIMixtapes offers several key features:
/// - Mood-based playlist generation
/// - Personality analysis for music preferences
/// - Real-time audio processing and analysis
/// - Asset management system
///
/// ## Getting Started
///
/// To begin using AIMixtapes, initialize the framework:
///
/// ```swift
/// do {
///     try AIMixtapes.initialize()
/// } catch {
///     print("Initialization failed: \(error)")
/// }
/// ```
///
/// ## Topics
///
/// ### Essentials
/// - ``initialize(with:)``
/// - ``reset()``
/// - ``version``
///
/// ### Configuration
/// - ``AIMixtapesConfig``
/// - ``config``
///
/// ### Types
/// - ``MoodColor``
/// - ``PersonalityColor``
/// - ``AudioFeatures``
/// - ``MixTapeModel``
///
public enum AIMixtapes {
    private static var isInitialized = false
    public static var config = AIMixtapesConfig()
    
    /// Initialize the AIMixtapes framework
    public static func initialize(with config: AIMixtapesConfig = AIMixtapesConfig()) throws {
        guard !isInitialized else { return }
        
        self.config = config
        
        // Set up audio session
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        
        // Validate assets
        guard Asset.validateAssets() else {
            throw AssetError.missingColor("Required assets missing")
        }
        
        isInitialized = true
    }
    
    /// Get the current version of the framework
    public static var version: String {
        return "1.0.0"
    }
    
    /// Reset the framework state
    public static func reset() {
        isInitialized = false
    }
}

// MARK: - Public Type Exports
public typealias MoodColor = Asset.MoodColor
public typealias PersonalityColor = Asset.PersonalityColor
public typealias AudioFeatures = AudioFeatures
public typealias MixTapeModel = MixTape

// MARK: - SwiftUI View Modifiers
extension View {
    /// Apply a mood-based color scheme to a view
    public func moodColor(_ mood: MoodColor, opacity: Double = 1.0) -> some View {
        self.modifier(MoodColorModifier(mood: mood, opacity: opacity))
    }
    
    /// Apply a personality-based color scheme to a view
    public func personalityColor(_ personality: PersonalityColor, opacity: Double = 1.0) -> some View {
        self.foregroundColor(personality.color.opacity(opacity))
    }
}
