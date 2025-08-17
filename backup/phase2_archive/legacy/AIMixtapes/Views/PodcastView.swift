import SwiftUI
import UniformTypeIdentifiers

struct PodcastView: View {
    @StateObject private var viewModel = PodcastViewModel()
    @State private var showFileImporter = false
    @State private var selectedURL: URL?

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isTranscribing {
                ProgressView("Transcribing podcast…")
            }
            if !viewModel.transcriptText.isEmpty {
                Group {
                    Text("Transcript")
                        .font(.headline)
                    ScrollView {
                        Text(viewModel.transcriptText)
                            .padding()
                    }
                    .frame(maxHeight: 150)
                }
            }
            if viewModel.isSummarizing {
                ProgressView("Summarizing transcript…")
            }
            if !viewModel.summaryText.isEmpty {
                Group {
                    Text("Summary")
                        .font(.headline)
                    ScrollView {
                        Text(viewModel.summaryText)
                            .padding()
                    }
                    .frame(maxHeight: 150)
                }
            }
            Spacer()
            Button(action: {
                showFileImporter = true
            }) {
                Text("Select Podcast Audio (MP3/WAV)")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType.audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    if let url = urls.first {
                        selectedURL = url
                        viewModel.handlePodcast(url: url)
                    }
                case let .failure(error):
                    print("File import error: \(error)")
                }
            }
        }
        .navigationTitle("Podcasts")
    }
}

struct PodcastView_Previews: PreviewProvider {
    static var previews: some View {
        PodcastView()
    }
}
