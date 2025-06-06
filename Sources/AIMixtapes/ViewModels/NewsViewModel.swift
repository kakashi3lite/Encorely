import Foundation

@MainActor
class NewsViewModel: ObservableObject {
    @Published var summaryText: String = ""
    @Published var isLoading: Bool = false
    
    init() {
        Task {
            do {
                try await NewsService.shared.initializeModel()
            } catch {
                print("Error initializing news model: \(error)")
            }
        }
    }
    
    /// Fetch and stream the latest news summary
    func fetchNewsSummary() {
        isLoading = true
        Task {
            do {
                let stream = try await NewsService.shared.summarizeLatestNews()
                summaryText = ""
                for try await token in stream {
                    summaryText += token
                }
                isLoading = false
            } catch {
                summaryText = "Failed to summarize news: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}