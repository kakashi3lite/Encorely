import AVFoundation
import Foundation

@MainActor
class PodcastViewModel: ObservableObject {
    @Published var transcriptText: String = ""
    @Published var summaryText: String = ""
    @Published var isTranscribing: Bool = false
    @Published var isSummarizing: Bool = false

    init() {
        Task {
            do {
                try await PodcastService.shared.initializeModel()
            } catch {
                print("Error initializing podcast model: \(error)")
            }
        }
    }

    /// Perform transcription of local audio file URL, then stream summary.
    func handlePodcast(url: URL) {
        isTranscribing = true
        isSummarizing = false
        transcriptText = ""
        summaryText = ""

        Task {
            do {
                let transcript = try await PodcastService.shared.transcribeAudio(from: url)
                transcriptText = transcript
                isTranscribing = false

                isSummarizing = true
                let stream = try await PodcastService.shared.summarizeTranscript(transcript)
                for try await token in stream {
                    summaryText += token
                }
                isSummarizing = false
            } catch {
                transcriptText = "Transcription failed: \(error.localizedDescription)"
                isTranscribing = false
            }
        }
    }
}
