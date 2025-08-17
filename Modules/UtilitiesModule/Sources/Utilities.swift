//
//  Utilities.swift
//  AI-Mixtapes
//
//  Created by AI Assistant on December 2024.
//  Copyright © 2024 AI-Mixtapes. All rights reserved.
//

import Foundation
import AVFoundation
import SwiftUI
import Accelerate

// MARK: - String Extensions

public extension String {
    /// Removes extra whitespace and normalizes text for processing
    var normalized: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    /// Extracts mood-related keywords from text
    var moodKeywords: [String] {
        let moodWords = [
            "happy", "sad", "excited", "calm", "angry", "peaceful",
            "energetic", "melancholy", "upbeat", "relaxed", "intense",
            "joyful", "somber", "vibrant", "mellow", "aggressive"
        ]
        
        let words = self.lowercased().components(separatedBy: .punctuationCharacters)
            .joined(separator: " ")
            .components(separatedBy: .whitespaces)
        
        return words.filter { moodWords.contains($0) }
    }
    
    /// Calculates sentiment score (-1.0 to 1.0)
    var sentimentScore: Double {
        let positiveWords = ["love", "amazing", "great", "awesome", "fantastic", "wonderful", "excellent"]
        let negativeWords = ["hate", "terrible", "awful", "horrible", "bad", "worst", "disgusting"]
        
        let words = self.lowercased().components(separatedBy: .punctuationCharacters)
            .joined(separator: " ")
            .components(separatedBy: .whitespaces)
        
        let positiveCount = words.filter { positiveWords.contains($0) }.count
        let negativeCount = words.filter { negativeWords.contains($0) }.count
        
        let totalWords = max(words.count, 1)
        return Double(positiveCount - negativeCount) / Double(totalWords)
    }
}

// MARK: - Date Extensions

public extension Date {
    /// Returns a human-readable time ago string
    var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Returns timestamp for audio analysis
    var audioTimestamp: TimeInterval {
        return self.timeIntervalSince1970
    }
    
    /// Creates date from audio timestamp
    static func fromAudioTimestamp(_ timestamp: TimeInterval) -> Date {
        return Date(timeIntervalSince1970: timestamp)
    }
}

// MARK: - Math Utilities

public struct MathUtils {
    /// Converts decibels to linear scale
    static func dbToLinear(_ db: Float) -> Float {
        return pow(10.0, db / 20.0)
    }
    
    /// Converts linear scale to decibels
    static func linearToDb(_ linear: Float) -> Float {
        return 20.0 * log10(max(linear, 1e-10))
    }
    
    /// Normalizes value to 0-1 range
    static func normalize(_ value: Float, min: Float, max: Float) -> Float {
        return (value - min) / (max - min)
    }
    
    /// Clamps value between min and max
    static func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
        return Swift.min(Swift.max(value, min), max)
    }
    
    /// Calculates RMS (Root Mean Square) of audio samples
    static func rms(of samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }
        
        var sum: Float = 0.0
        vDSP_svesq(samples, 1, &sum, vDSP_Length(samples.count))
        return sqrt(sum / Float(samples.count))
    }
    
    /// Calculates zero crossing rate
    static func zeroCrossingRate(of samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0.0 }
        
        var crossings = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0) != (samples[i-1] >= 0) {
                crossings += 1
            }
        }
        
        return Float(crossings) / Float(samples.count - 1)
    }
}

// MARK: - Collection Extensions

public extension Array where Element == Float {
    /// Applies Hann window to audio samples
    var hannWindowed: [Float] {
        let count = self.count
        guard count > 1 else { return self }
        
        var windowed = [Float](repeating: 0.0, count: count)
        
        for i in 0..<count {
            let window = 0.5 * (1.0 - cos(2.0 * Float.pi * Float(i) / Float(count - 1)))
            windowed[i] = self[i] * window
        }
        
        return windowed
    }
    
    /// Applies Hamming window to audio samples
    var hammingWindowed: [Float] {
        let count = self.count
        guard count > 1 else { return self }
        
        var windowed = [Float](repeating: 0.0, count: count)
        
        for i in 0..<count {
            let window = 0.54 - 0.46 * cos(2.0 * Float.pi * Float(i) / Float(count - 1))
            windowed[i] = self[i] * window
        }
        
        return windowed
    }
    
    /// Calculates spectral centroid
    var spectralCentroid: Float {
        guard !self.isEmpty else { return 0.0 }
        
        var weightedSum: Float = 0.0
        var magnitudeSum: Float = 0.0
        
        for (index, magnitude) in self.enumerated() {
            let frequency = Float(index)
            weightedSum += frequency * magnitude
            magnitudeSum += magnitude
        }
        
        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0.0
    }
}

// MARK: - Audio Utilities

public struct AudioUtils {
    /// Standard sample rates
    public enum SampleRate: Float, CaseIterable {
        case rate8kHz = 8000
        case rate16kHz = 16000
        case rate22kHz = 22050
        case rate44kHz = 44100
        case rate48kHz = 48000
        case rate96kHz = 96000
        
        var description: String {
            return "\(Int(self.rawValue)) Hz"
        }
    }
    
    /// Converts sample rate
    static func convertSampleRate(from samples: [Float], 
                                fromRate: Float, 
                                toRate: Float) -> [Float] {
        guard fromRate != toRate else { return samples }
        
        let ratio = toRate / fromRate
        let newCount = Int(Float(samples.count) * ratio)
        var converted = [Float](repeating: 0.0, count: newCount)
        
        for i in 0..<newCount {
            let sourceIndex = Float(i) / ratio
            let lowerIndex = Int(floor(sourceIndex))
            let upperIndex = min(lowerIndex + 1, samples.count - 1)
            let fraction = sourceIndex - Float(lowerIndex)
            
            if lowerIndex < samples.count {
                converted[i] = samples[lowerIndex] * (1.0 - fraction) + 
                              samples[upperIndex] * fraction
            }
        }
        
        return converted
    }
    
    /// Converts audio format
    static func convertFormat(_ buffer: AVAudioPCMBuffer, 
                            to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            return nil
        }
        
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * 
                                       format.sampleRate / buffer.format.sampleRate)
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, 
                                                   frameCapacity: capacity) else {
            return nil
        }
        
        var error: NSError?
        let status = converter.convert(to: convertedBuffer, 
                                     error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        return status == .haveData ? convertedBuffer : nil
    }
    
    /// Calculates frequency from bin index
    static func frequency(forBin bin: Int, sampleRate: Float, fftSize: Int) -> Float {
        return Float(bin) * sampleRate / Float(fftSize)
    }
    
    /// Calculates bin index from frequency
    static func bin(forFrequency frequency: Float, sampleRate: Float, fftSize: Int) -> Int {
        return Int(frequency * Float(fftSize) / sampleRate)
    }
}

// MARK: - UI Utilities

public struct UIUtils {
    /// Color manipulation utilities
    public struct ColorUtils {
        /// Generates mood-based colors
        static func color(for mood: String) -> Color {
            switch mood.lowercased() {
            case "happy", "joyful", "excited":
                return Color.yellow
            case "sad", "melancholy", "somber":
                return Color.blue
            case "calm", "peaceful", "relaxed":
                return Color.green
            case "angry", "aggressive", "intense":
                return Color.red
            case "energetic", "vibrant", "upbeat":
                return Color.orange
            default:
                return Color.gray
            }
        }
        
        /// Generates personality-based colors
        static func color(for personality: String) -> Color {
            switch personality.lowercased() {
            case "enthusiast":
                return Color.orange
            case "artist":
                return Color.purple
            case "thinker":
                return Color.blue
            case "helper":
                return Color.green
            case "achiever":
                return Color.red
            case "individualist":
                return Color.indigo
            case "investigator":
                return Color.cyan
            case "loyalist":
                return Color.brown
            default:
                return Color.gray
            }
        }
        
        /// Interpolates between two colors
        static func interpolate(from: Color, to: Color, progress: Double) -> Color {
            let clampedProgress = MathUtils.clamp(progress, min: 0.0, max: 1.0)
            
            #if os(iOS)
            let fromUIColor = UIColor(from)
            let toUIColor = UIColor(to)
            
            var fromRed: CGFloat = 0, fromGreen: CGFloat = 0, fromBlue: CGFloat = 0, fromAlpha: CGFloat = 0
            var toRed: CGFloat = 0, toGreen: CGFloat = 0, toBlue: CGFloat = 0, toAlpha: CGFloat = 0
            
            fromUIColor.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)
            toUIColor.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)
            
            let red = fromRed + (toRed - fromRed) * clampedProgress
            let green = fromGreen + (toGreen - fromGreen) * clampedProgress
            let blue = fromBlue + (toBlue - fromBlue) * clampedProgress
            let alpha = fromAlpha + (toAlpha - fromAlpha) * clampedProgress
            
            return Color(red: red, green: green, blue: blue, opacity: alpha)
            #else
            // macOS implementation would go here
            return from
            #endif
        }
    }
    
    /// Animation utilities
    public struct AnimationUtils {
        /// Standard easing curves
        static let easeInOut = Animation.easeInOut(duration: 0.3)
        static let spring = Animation.spring(response: 0.5, dampingFraction: 0.8)
        static let bouncy = Animation.spring(response: 0.3, dampingFraction: 0.6)
        
        /// Custom timing curves
        static func customEase(duration: Double) -> Animation {
            return Animation.timingCurve(0.25, 0.1, 0.25, 1.0, duration: duration)
        }
    }
    
    /// Layout utilities
    public struct LayoutUtils {
        /// Safe area insets
        static var safeAreaInsets: EdgeInsets {
            #if os(iOS)
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            
            let insets = window?.safeAreaInsets ?? .zero
            return EdgeInsets(top: insets.top, 
                            leading: insets.left, 
                            bottom: insets.bottom, 
                            trailing: insets.right)
            #else
            return EdgeInsets()
            #endif
        }
        
        /// Calculates optimal grid columns for given width
        static func gridColumns(for width: CGFloat, minItemWidth: CGFloat = 150) -> Int {
            return max(1, Int(width / minItemWidth))
        }
    }
}

// MARK: - Accessibility Utilities

public struct AccessibilityUtils {
    /// Generates accessibility labels for audio features
    static func label(for audioFeatures: [String: Float]) -> String {
        var components: [String] = []
        
        if let energy = audioFeatures["energy"] {
            let energyLevel = energy > 0.7 ? "high energy" : energy > 0.3 ? "medium energy" : "low energy"
            components.append(energyLevel)
        }
        
        if let valence = audioFeatures["valence"] {
            let mood = valence > 0.6 ? "positive mood" : valence > 0.4 ? "neutral mood" : "negative mood"
            components.append(mood)
        }
        
        if let tempo = audioFeatures["tempo"] {
            let tempoDescription = tempo > 120 ? "fast tempo" : tempo > 80 ? "medium tempo" : "slow tempo"
            components.append(tempoDescription)
        }
        
        return components.joined(separator: ", ")
    }
    
    /// Generates accessibility hints for UI actions
    static func hint(for action: String) -> String {
        switch action {
        case "play":
            return "Double tap to play the mixtape"
        case "pause":
            return "Double tap to pause playback"
        case "skip":
            return "Double tap to skip to next track"
        case "analyze":
            return "Double tap to analyze audio features"
        case "generate":
            return "Double tap to generate new mixtape"
        default:
            return "Double tap to activate"
        }
    }
}

// MARK: - Performance Utilities

public struct PerformanceUtils {
    /// Measures execution time of a block
    static func measureTime<T>(_ block: () throws -> T) rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result, timeElapsed)
    }
    
    /// Debounces function calls
    static func debounce(delay: TimeInterval, action: @escaping () -> Void) -> () -> Void {
        var workItem: DispatchWorkItem?
        
        return {
            workItem?.cancel()
            workItem = DispatchWorkItem(block: action)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
        }
    }
    
    /// Throttles function calls
    static func throttle(interval: TimeInterval, action: @escaping () -> Void) -> () -> Void {
        var lastExecutionTime: TimeInterval = 0
        
        return {
            let currentTime = CFAbsoluteTimeGetCurrent()
            if currentTime - lastExecutionTime >= interval {
                lastExecutionTime = currentTime
                action()
            }
        }
    }
}

// MARK: - Validation Utilities

public struct ValidationUtils {
    /// Validates audio file format
    static func isValidAudioFile(_ url: URL) -> Bool {
        let validExtensions = ["mp3", "wav", "m4a", "aac", "flac"]
        let fileExtension = url.pathExtension.lowercased()
        return validExtensions.contains(fileExtension)
    }
    
    /// Validates audio sample rate
    static func isValidSampleRate(_ sampleRate: Double) -> Bool {
        let validRates: [Double] = [8000, 16000, 22050, 44100, 48000, 96000]
        return validRates.contains(sampleRate)
    }
    
    /// Validates buffer size for audio processing
    static func isValidBufferSize(_ size: Int) -> Bool {
        // Buffer size should be a power of 2 for efficient FFT
        return size > 0 && (size & (size - 1)) == 0
    }
}