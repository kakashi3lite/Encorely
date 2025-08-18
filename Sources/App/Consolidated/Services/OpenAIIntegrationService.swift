import AudioKit
import Foundation
import OpenAI
import os.log

import SwiftUI

/// Service responsible for AI-powered features in the application
final class OpenAIIntegrationService: ObservableObject {
    private let logger = Logger(subsystem: "com.aimixtures.ai", category: "AIIntegration")
    private let openAI: OpenAI

    // MARK: - Configuration

    private enum Config {
        static let model = "gpt-4"
        static let maxTokens = 2048
        static let temperature = 0.7
    }

    // MARK: - Published Properties

    @Published var isProcessing = false
    @Published var currentMood: String?
    @Published var generationError: Error?

    // MARK: - Initialization

    init(openAI: OpenAI) {
        self.openAI = openAI
        logger.info("OpenAIIntegrationService initialized")
    }

    // MARK: - Public Methods

    func analyzeMood(for audioFeatures: AudioFeatures) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }

        do {
            let prompt = buildMoodAnalysisPrompt(from: audioFeatures)
            let response = try await openAI.completions.create(
                model: Config.model,
                prompt: prompt,
                maxTokens: Config.maxTokens,
                temperature: Config.temperature
            )

            guard let mood = response.choices.first?.text.trimmingCharacters(in: .whitespacesAndNewlines) else {
                throw AIError.emptyResponse
            }

            currentMood = mood
            return mood

        } catch {
            logger.error("Failed to analyze mood: \(error.localizedDescription)")
            generationError = error
            throw error
        }
    }

    // MARK: - Private Methods

    private func buildMoodAnalysisPrompt(from features: AudioFeatures) -> String {
        """
        Based on the following audio features:
        - Energy: \(features.energy)
        - Tempo: \(features.tempo) BPM
        - Key: \(features.key)
        - Mode: \(features.mode)
        - Valence: \(features.valence)

        Please analyze and describe the mood of this music in 2-3 words.
        """
    }
}

// MARK: - Error Types

extension AIIntegrationService {
    enum AIError: LocalizedError {
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .emptyResponse:
                "The AI did not provide a response"
            }
        }
    }
}
