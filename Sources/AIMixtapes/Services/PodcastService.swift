import Foundation
import AVFoundation
import Speech
import LocalLLMClient
import LocalLLMClientLlama
import LocalLLMClientMLX

/// A service that handles podcast transcription and summarization on-device.
public class PodcastService {
    public static let shared = PodcastService()
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var audioEngine = AVAudioEngine()
    private var model: LLMModel?
    private var session: LLMStreamSession?

    /// Initialize (load) the best LLM model for podcast summarization.
    public func initializeModel() async throws {
        if let mlxModel = try? MLXModel(name: "MobileLLM-3B") {
            model = .mlx(mlxModel)
        } else {
            let hfID = "lmstudio-community/gemma-3-4B-it-qat-GGUF"
            let downloader = FileDownloader(source: .huggingFace(id: hfID, globs: ["gemma-3-4B-it-q4_0.gguf"]))
            try await downloader.download { _ in }
            guard let localURL = try? downloader.cachedURL(glob: "gemma-3-4B-it-q4_0.gguf") else {
                throw NSError(domain: "PodcastService", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to locate downloaded GGUF"
                ])
            }
            let llamaModel = try LlamaModel(path: localURL.path)
            model = .llama(llamaModel)
        }
    }

    /// Transcribe the given audio URL (e.g., a local .mp3 or .wav) to text.
    public func transcribeAudio(from url: URL) async throws -> String {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameLength = UInt32(audioFile.length)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength)!
        try audioFile.read(into: buffer)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = false

        let node = audioEngine.inputNode
        let recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { result, error in
            // Not used—see below
        }

        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { (buffer, _) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        recognitionRequest?.append(buffer)

        var finalText = ""
        if let task = speechRecognizer?.recognitionTask(with: recognitionRequest!) { result, error in
            if let res = result, res.isFinal {
                finalText = res.bestTranscription.formattedString
                self.audioEngine.stop()
                self.recognitionRequest?.endAudio()
            }
        } {
            while finalText.isEmpty && !task.isCancelled {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        return finalText
    }

    /// Summarize a transcript string via LocalLLMClient, returning an AsyncStream of tokens.
    public func summarizeTranscript(_ transcript: String) async throws -> AsyncStream<String> {
        guard let model = model else {
            throw NSError(domain: "PodcastService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Model not initialized. Call initializeModel() first."
            ])
        }
        if session == nil {
            let config = GenerationConfig(
                maxTokens: 150,
                temperature: 0.6,
                topK: 40,
                topP: 0.9
            )
            session = try await LLMStreamSession(model: model, config: config)
        }
        let prompt = "Summarize this podcast transcription in 2 sentences: \"\(transcript)\""
        return session!.stream(prompt: prompt)
    }
}