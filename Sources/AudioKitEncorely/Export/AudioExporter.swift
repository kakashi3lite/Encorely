import Foundation
import AVFoundation
import UniformTypeIdentifiers
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Professional Audio Export Engine
@MainActor
public class AudioExporter: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isExporting = false
    @Published public private(set) var exportProgress: Float = 0.0
    @Published public private(set) var availableFormats: [ExportFormat] = []
    @Published public private(set) var exportError: AudioExportError?
    @Published public private(set) var lastExportResult: ExportResult?
    
    // MARK: - Export Formats
    public enum ExportFormat: String, CaseIterable, Identifiable {
        case wav = "wav"
        case aiff = "aiff"
        case m4a = "m4a"
        case mp3 = "mp3"
        case flac = "flac"
        case caf = "caf"
        
        public var id: String { rawValue }
        
        public var displayName: String {
            switch self {
            case .wav: return "WAV (Uncompressed)"
            case .aiff: return "AIFF (Apple)"
            case .m4a: return "M4A (AAC)"
            case .mp3: return "MP3 (Universal)"
            case .flac: return "FLAC (Lossless)"
            case .caf: return "CAF (Apple Core Audio)"
            }
        }
        
        public var description: String {
            switch self {
            case .wav: return "Highest quality, large file size"
            case .aiff: return "Professional quality, Apple format"
            case .m4a: return "Good quality, medium file size"
            case .mp3: return "Universal compatibility, smaller files"
            case .flac: return "Lossless compression, good quality"
            case .caf: return "Apple's professional audio format"
            }
        }
        
        public var fileExtension: String { rawValue }
        
        public var icon: String {
            switch self {
            case .wav, .aiff, .flac: return "waveform"
            case .m4a, .mp3: return "music.note"
            case .caf: return "doc.audio"
            }
        }
        
        public var isProfessional: Bool {
            switch self {
            case .wav, .aiff, .flac, .caf: return true
            case .m4a, .mp3: return false
            }
        }
        
        public var formatID: AudioFormatID {
            switch self {
            case .wav, .aiff: return kAudioFormatLinearPCM
            case .m4a: return kAudioFormatMPEG4AAC
            case .mp3: return kAudioFormatMPEGLayer3
            case .flac: return kAudioFormatFLAC
            case .caf: return kAudioFormatAppleLossless
            }
        }
        
        public var qualitySettings: [String: Any] {
            switch self {
            case .wav:
                return [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM),
                    AVLinearPCMBitDepthKey: 24,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsFloatKey: false
                ]
            case .aiff:
                return [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM),
                    AVLinearPCMBitDepthKey: 24,
                    AVLinearPCMIsBigEndianKey: true,
                    AVLinearPCMIsFloatKey: false
                ]
            case .m4a:
                return [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
                    AVEncoderBitRateKey: 320000
                ]
            case .mp3:
                return [
                    AVFormatIDKey: Int(kAudioFormatMPEGLayer3),
                    AVEncoderBitRateKey: 320000,
                    AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
                ]
            case .flac:
                return [
                    AVFormatIDKey: Int(kAudioFormatFLAC),
                    AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
                ]
            case .caf:
                return [
                    AVFormatIDKey: Int(kAudioFormatAppleLossless),
                    AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
                ]
            }
        }
    }
    
    // MARK: - Export Quality
    public enum ExportQuality: String, CaseIterable {
        case draft = "draft"
        case good = "good"
        case professional = "professional"
        case mastered = "mastered"
        
        public var displayName: String {
            switch self {
            case .draft: return "Draft (22kHz)"
            case .good: return "Good (44.1kHz)"
            case .professional: return "Professional (48kHz)"
            case .mastered: return "Mastered (96kHz)"
            }
        }
        
        public var sampleRate: Double {
            switch self {
            case .draft: return 22050
            case .good: return 44100
            case .professional: return 48000
            case .mastered: return 96000
            }
        }
        
        public var bitDepth: Int {
            switch self {
            case .draft: return 16
            case .good: return 16
            case .professional: return 24
            case .mastered: return 32
            }
        }
        
        public var isPremium: Bool {
            switch self {
            case .draft, .good: return false
            case .professional, .mastered: return true
            }
        }
    }
    
    // MARK: - Export Configuration
    public struct ExportConfiguration {
        public let format: ExportFormat
        public let quality: ExportQuality
        public let normalizeAudio: Bool
        public let fadeIn: TimeInterval
        public let fadeOut: TimeInterval
        public let trimSilence: Bool
        public let addMetadata: Bool
        public let customMetadata: AudioMetadata?
        
        public struct AudioMetadata {
            public let title: String?
            public let artist: String?
            public let album: String?
            public let genre: String?
            public let year: Int?
            public let comment: String?
            #if canImport(UIKit)
            public let artwork: UIImage?
            #endif
            
            #if canImport(UIKit)
            public init(
                title: String? = nil,
                artist: String? = nil,
                album: String? = nil,
                genre: String? = nil,
                year: Int? = nil,
                comment: String? = nil,
                artwork: UIImage? = nil
            ) {
                self.title = title
                self.artist = artist
                self.album = album
                self.genre = genre
                self.year = year
                self.comment = comment
                self.artwork = artwork
            }
            #else
            public init(
                title: String? = nil,
                artist: String? = nil,
                album: String? = nil,
                genre: String? = nil,
                year: Int? = nil,
                comment: String? = nil
            ) {
                self.title = title
                self.artist = artist
                self.album = album
                self.genre = genre
                self.year = year
                self.comment = comment
            }
            #endif
        }
        
        public init(
            format: ExportFormat = .m4a,
            quality: ExportQuality = .good,
            normalizeAudio: Bool = true,
            fadeIn: TimeInterval = 0.0,
            fadeOut: TimeInterval = 0.0,
            trimSilence: Bool = false,
            addMetadata: Bool = true,
            customMetadata: AudioMetadata? = nil
        ) {
            self.format = format
            self.quality = quality
            self.normalizeAudio = normalizeAudio
            self.fadeIn = fadeIn
            self.fadeOut = fadeOut
            self.trimSilence = trimSilence
            self.addMetadata = addMetadata
            self.customMetadata = customMetadata
        }
    }
    
    // MARK: - Export Destinations
    public enum ExportDestination {
        case files
        case share
        case cloud(CloudProvider)
        case airdrop
        case email
        case socialMedia(SocialPlatform)
        
        public enum CloudProvider: String, CaseIterable {
            case icloud = "icloud"
            case dropbox = "dropbox"
            case googledrive = "googledrive"
            case onedrive = "onedrive"
            
            public var displayName: String {
                switch self {
                case .icloud: return "iCloud Drive"
                case .dropbox: return "Dropbox"
                case .googledrive: return "Google Drive"
                case .onedrive: return "OneDrive"
                }
            }
            
            public var icon: String {
                switch self {
                case .icloud: return "icloud"
                case .dropbox: return "cloud"
                case .googledrive: return "cloud"
                case .onedrive: return "cloud"
                }
            }
        }
        
        public enum SocialPlatform: String, CaseIterable {
            case instagram = "instagram"
            case tiktok = "tiktok"
            case twitter = "twitter"
            case facebook = "facebook"
            case youtube = "youtube"
            case soundcloud = "soundcloud"
            
            public var displayName: String {
                switch self {
                case .instagram: return "Instagram"
                case .tiktok: return "TikTok"
                case .twitter: return "Twitter/X"
                case .facebook: return "Facebook"
                case .youtube: return "YouTube"
                case .soundcloud: return "SoundCloud"
                }
            }
            
            public var icon: String {
                switch self {
                case .instagram: return "camera"
                case .tiktok: return "music.note"
                case .twitter: return "bird"
                case .facebook: return "person.3"
                case .youtube: return "play.rectangle"
                case .soundcloud: return "cloud"
                }
            }
            
            public var recommendedFormat: ExportFormat {
                switch self {
                case .instagram, .tiktok: return .m4a
                case .twitter, .facebook: return .mp3
                case .youtube, .soundcloud: return .wav
                }
            }
        }
    }
    
    // MARK: - Export Result
    public struct ExportResult {
        public let originalURL: URL
        public let exportedURL: URL
        public let configuration: ExportConfiguration
        public let destination: ExportDestination?
        public let fileSize: Int64
        public let exportTime: TimeInterval
        public let success: Bool
        public let timestamp: Date
    }
    
    // MARK: - Initialization
    public init() {
        setupAvailableFormats()
    }
    
    // MARK: - Main Export Functions
    public func exportAudio(
        from sourceURL: URL,
        configuration: ExportConfiguration,
        to destination: ExportDestination = .files
    ) async throws -> ExportResult {
        
        guard !isExporting else {
            throw AudioExportError.exportInProgress
        }
        
        isExporting = true
        exportProgress = 0.0
        exportError = nil
        
        let startTime = Date()
        
        do {
            // Step 1: Load and validate source audio
            let sourceBuffer = try loadSourceAudio(from: sourceURL)
            exportProgress = 0.2
            
            // Step 2: Process audio (normalize, fade, trim)
            let processedBuffer = try await processAudio(
                buffer: sourceBuffer,
                configuration: configuration
            )
            exportProgress = 0.6
            
            // Step 3: Convert to target format
            let exportURL = try await convertAndSave(
                buffer: processedBuffer,
                configuration: configuration,
                sourceURL: sourceURL
            )
            exportProgress = 0.8
            
            // Step 4: Add metadata if requested
            if configuration.addMetadata {
                try await addMetadata(to: exportURL, configuration: configuration)
            }
            exportProgress = 0.9
            
            // Step 5: Handle destination
            let finalURL = try await handleDestination(
                exportURL: exportURL,
                destination: destination
            )
            exportProgress = 1.0
            
            let fileSize = getFileSize(url: finalURL)
            let exportTime = Date().timeIntervalSince(startTime)
            
            let result = ExportResult(
                originalURL: sourceURL,
                exportedURL: finalURL,
                configuration: configuration,
                destination: destination,
                fileSize: fileSize,
                exportTime: exportTime,
                success: true,
                timestamp: Date()
            )
            
            lastExportResult = result
            isExporting = false
            
            return result
            
        } catch {
            isExporting = false
            exportError = AudioExportError.from(error)
            
            let result = ExportResult(
                originalURL: sourceURL,
                exportedURL: sourceURL,
                configuration: configuration,
                destination: destination,
                fileSize: 0,
                exportTime: Date().timeIntervalSince(startTime),
                success: false,
                timestamp: Date()
            )
            
            lastExportResult = result
            throw error
        }
    }
    
    // MARK: - Batch Export
    public func exportMultipleFiles(
        urls: [URL],
        configuration: ExportConfiguration,
        destination: ExportDestination = .files
    ) async throws -> [ExportResult] {
        
        var results: [ExportResult] = []
        
        for (index, url) in urls.enumerated() {
            let result = try await exportAudio(
                from: url,
                configuration: configuration,
                to: destination
            )
            results.append(result)
            
            // Update overall progress
            let overallProgress = Float(index + 1) / Float(urls.count)
            await MainActor.run {
                self.exportProgress = overallProgress
            }
        }
        
        return results
    }
    
    // MARK: - Quick Export Presets
    public func quickExportForSocialMedia(
        from sourceURL: URL,
        platform: ExportDestination.SocialPlatform
    ) async throws -> ExportResult {
        
        let configuration = ExportConfiguration(
            format: platform.recommendedFormat,
            quality: .good,
            normalizeAudio: true,
            fadeIn: 0.0,
            fadeOut: 0.5,
            trimSilence: true,
            addMetadata: true,
            customMetadata: ExportConfiguration.AudioMetadata(
                title: "Audio Recording",
                artist: "Encorely App",
                comment: "Created with Encorely"
            )
        )
        
        return try await exportAudio(
            from: sourceURL,
            configuration: configuration,
            to: .socialMedia(platform)
        )
    }
    
    public func quickExportProfessional(
        from sourceURL: URL
    ) async throws -> ExportResult {
        
        let configuration = ExportConfiguration(
            format: .wav,
            quality: .professional,
            normalizeAudio: false,
            fadeIn: 0.0,
            fadeOut: 0.0,
            trimSilence: false,
            addMetadata: true
        )
        
        return try await exportAudio(
            from: sourceURL,
            configuration: configuration,
            to: .files
        )
    }
    
    // MARK: - Private Implementation
    private func setupAvailableFormats() {
        availableFormats = ExportFormat.allCases
    }
    
    private func loadSourceAudio(from url: URL) throws -> AVAudioPCMBuffer {
        let audioFile = try AVAudioFile(forReading: url)
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(audioFile.length)
        ) else {
            throw AudioExportError.bufferCreationFailed
        }
        
        try audioFile.read(into: buffer)
        return buffer
    }
    
    private func processAudio(
        buffer: AVAudioPCMBuffer,
        configuration: ExportConfiguration
    ) async throws -> AVAudioPCMBuffer {
        
        var processedBuffer = buffer
        
        // Apply normalization
        if configuration.normalizeAudio {
            processedBuffer = try normalizeAudio(buffer: processedBuffer)
        }
        
        // Apply fades
        if configuration.fadeIn > 0 || configuration.fadeOut > 0 {
            processedBuffer = try applyFades(
                buffer: processedBuffer,
                fadeIn: configuration.fadeIn,
                fadeOut: configuration.fadeOut
            )
        }
        
        // Trim silence
        if configuration.trimSilence {
            processedBuffer = try trimSilence(buffer: processedBuffer)
        }
        
        return processedBuffer
    }
    
    private func normalizeAudio(buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let inputData = buffer.floatChannelData?[0],
              let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: buffer.format,
                frameCapacity: buffer.frameCapacity
              ),
              let outputData = outputBuffer.floatChannelData?[0] else {
            throw AudioExportError.processingFailed
        }
        
        let frameCount = Int(buffer.frameLength)
        outputBuffer.frameLength = buffer.frameLength
        
        // Find peak value
        var peak: Float = 0.0
        for i in 0..<frameCount {
            peak = max(peak, abs(inputData[i]))
        }
        
        // Apply normalization
        let gain = peak > 0 ? 0.95 / peak : 1.0
        for i in 0..<frameCount {
            outputData[i] = inputData[i] * gain
        }
        
        return outputBuffer
    }
    
    private func applyFades(
        buffer: AVAudioPCMBuffer,
        fadeIn: TimeInterval,
        fadeOut: TimeInterval
    ) throws -> AVAudioPCMBuffer {
        
        guard let inputData = buffer.floatChannelData?[0],
              let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: buffer.format,
                frameCapacity: buffer.frameCapacity
              ),
              let outputData = outputBuffer.floatChannelData?[0] else {
            throw AudioExportError.processingFailed
        }
        
        let frameCount = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)
        
        let fadeInFrames = Int(fadeIn * Double(sampleRate))
        let fadeOutFrames = Int(fadeOut * Double(sampleRate))
        
        outputBuffer.frameLength = buffer.frameLength
        
        for i in 0..<frameCount {
            var sample = inputData[i]
            
            // Apply fade in
            if i < fadeInFrames {
                let fadeGain = Float(i) / Float(fadeInFrames)
                sample *= fadeGain
            }
            
            // Apply fade out
            if i >= frameCount - fadeOutFrames {
                let fadeGain = Float(frameCount - i) / Float(fadeOutFrames)
                sample *= fadeGain
            }
            
            outputData[i] = sample
        }
        
        return outputBuffer
    }
    
    private func trimSilence(buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        // Simplified silence trimming
        guard let inputData = buffer.floatChannelData?[0] else {
            throw AudioExportError.processingFailed
        }
        
        let frameCount = Int(buffer.frameLength)
        let threshold: Float = 0.01
        
        // Find start and end of audio content
        var startFrame = 0
        var endFrame = frameCount - 1
        
        // Find first non-silent frame
        for i in 0..<frameCount {
            if abs(inputData[i]) > threshold {
                startFrame = i
                break
            }
        }
        
        // Find last non-silent frame
        for i in (0..<frameCount).reversed() {
            if abs(inputData[i]) > threshold {
                endFrame = i
                break
            }
        }
        
        let trimmedLength = endFrame - startFrame + 1
        
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: AVAudioFrameCount(trimmedLength)
        ),
              let outputData = outputBuffer.floatChannelData?[0] else {
            throw AudioExportError.processingFailed
        }
        
        outputBuffer.frameLength = AVAudioFrameCount(trimmedLength)
        
        for i in 0..<trimmedLength {
            outputData[i] = inputData[startFrame + i]
        }
        
        return outputBuffer
    }
    
    private func convertAndSave(
        buffer: AVAudioPCMBuffer,
        configuration: ExportConfiguration,
        sourceURL: URL
    ) async throws -> URL {
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = sourceURL.deletingPathExtension().lastPathComponent
        let outputFileName = "\(fileName)_exported.\(configuration.format.fileExtension)"
        let outputURL = documentsPath.appendingPathComponent(outputFileName)
        
        var settings = configuration.format.qualitySettings
        settings[AVSampleRateKey] = configuration.quality.sampleRate
        settings[AVNumberOfChannelsKey] = buffer.format.channelCount
        
        // Add bit depth for PCM formats
        if configuration.format == .wav || configuration.format == .aiff {
            settings[AVLinearPCMBitDepthKey] = configuration.quality.bitDepth
        }
        
        let audioFile = try AVAudioFile(forWriting: outputURL, settings: settings)
        try audioFile.write(from: buffer)
        
        return outputURL
    }
    
    private func addMetadata(
        to url: URL,
        configuration: ExportConfiguration
    ) async throws {
        // Add metadata using AVMutableMetadataItem
        // Implementation would depend on format support
    }
    
    private func handleDestination(
        exportURL: URL,
        destination: ExportDestination
    ) async throws -> URL {
        
        switch destination {
        case .files:
            return exportURL
            
        case .share:
            // Present share sheet
            await presentShareSheet(for: exportURL)
            return exportURL
            
        case .cloud(let provider):
            return try await uploadToCloud(url: exportURL, provider: provider)
            
        case .airdrop:
            await presentAirDrop(for: exportURL)
            return exportURL
            
        case .email:
            await presentEmailComposer(for: exportURL)
            return exportURL
            
        case .socialMedia(let platform):
            return try await prepareForSocialMedia(url: exportURL, platform: platform)
        }
    }
    
    private func presentShareSheet(for url: URL) async {
        // Implementation for presenting iOS share sheet
    }
    
    private func uploadToCloud(url: URL, provider: ExportDestination.CloudProvider) async throws -> URL {
        // Implementation for cloud upload
        return url // Placeholder
    }
    
    private func presentAirDrop(for url: URL) async {
        // Implementation for AirDrop
    }
    
    private func presentEmailComposer(for url: URL) async {
        // Implementation for email composer
    }
    
    private func prepareForSocialMedia(url: URL, platform: ExportDestination.SocialPlatform) async throws -> URL {
        // Implementation for social media preparation
        return url // Placeholder
    }
    
    private func getFileSize(url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}

// MARK: - Error Handling
public enum AudioExportError: LocalizedError {
    case exportInProgress
    case bufferCreationFailed
    case processingFailed
    case conversionFailed
    case metadataFailed
    case destinationFailed
    case unsupportedFormat
    case insufficientSpace
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .exportInProgress:
            return "Audio export is already in progress"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .processingFailed:
            return "Audio processing failed"
        case .conversionFailed:
            return "Format conversion failed"
        case .metadataFailed:
            return "Failed to add metadata"
        case .destinationFailed:
            return "Failed to save to destination"
        case .unsupportedFormat:
            return "Audio format not supported"
        case .insufficientSpace:
            return "Insufficient storage space"
        case .unknown(let error):
            return "Export error: \(error.localizedDescription)"
        }
    }
    
    static func from(_ error: Error) -> AudioExportError {
        if let exportError = error as? AudioExportError {
            return exportError
        }
        return .unknown(error)
    }
}