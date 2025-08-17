import Foundation
import LocalLLMClient
import LocalLLMClientLlama
import LocalLLMClientMLX

/// A singleton service for summarizing live news on-device.
public class NewsService {
    public static let shared = NewsService()
    private var model: LLMModel?
    private var session: LLMStreamSession?

    /// Initialize (load) the best available model for news summarization.
    /// This tries to load an MLX .mlpackage first; if unavailable, falls back to llama.cpp GGUF.
    public func initializeModel() async throws {
        // Attempt to load an MLX model (MobileLLM-3B) from the bundle or cache.
        if let mlxModel = try? MLXModel(name: "MobileLLM-3B") {
            print("Loaded MobileLLM-3B via MLX for news summarization")
            model = .mlx(mlxModel)
        } else {
            // Otherwise, download or load a GGUF from Hugging Face (Gemma 3 4B QAT).
            let hfID = "lmstudio-community/gemma-3-4B-it-qat-GGUF"
            let downloader = FileDownloader(source: .huggingFace(id: hfID, globs: ["gemma-3-4B-it-q4_0.gguf"]))
            try await downloader.download { progress in
                print("News model download: \(Int(progress * 100))%")
            }
            guard let localURL = try? downloader.cachedURL(glob: "gemma-3-4B-it-q4_0.gguf") else {
                throw NSError(domain: "NewsService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to locate downloaded GGUF",
                ])
            }
            let llamaModel = try LlamaModel(path: localURL.path)
            print("Loaded GGUF via llama.cpp for news summarization")
            model = .llama(llamaModel)
        }
    }

    /// Returns an AsyncStream of tokens summarizing the latest headlines.
    public func summarizeLatestNews() async throws -> AsyncStream<String> {
        guard let model else {
            throw NSError(domain: "NewsService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Model not initialized. Call initializeModel() first.",
            ])
        }
        // Create a streaming session if needed
        if session == nil {
            let config = GenerationConfig(
                maxTokens: 200,
                temperature: 0.5,
                topK: 50,
                topP: 0.9
            )
            session = try await LLMStreamSession(model: model, config: config)
        }
        let prompt = "Summarize the top tech and music news headlines in 3 concise sentences:"
        return session!.stream(prompt: prompt)
    }
}
