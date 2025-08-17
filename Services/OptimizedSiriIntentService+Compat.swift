// Thin compatibility extension bridging to the canonical implementation.
import Foundation
import Intents

extension OptimizedSiriIntentService {
    /// Convenience wrapper to handle a simple PlayMood phrase via Siri
    /// - Parameter phrase: e.g., "play happy mood"
    /// - Returns: A boolean indicating if the phrase could be scheduled for handling
    @discardableResult
    public func handleSimplePhrase(_ phrase: String) -> Bool {
        // Basic sanitization; real routing happens in the consolidated service methods
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return false }
        // Emit a lightweight notification used by the consolidated service to pick up quick requests
        NotificationCenter.default.post(name: .init("OptimizedSiriIntentService.SimplePhrase"), object: trimmed)
        return true
    }
}
