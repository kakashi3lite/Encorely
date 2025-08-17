import SwiftUI

struct NewsView: View {
    @StateObject private var viewModel = NewsViewModel()

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView("Summarizing news…")
            }
            ScrollView {
                Text(viewModel.summaryText)
                    .padding()
            }
            Spacer()
            Button(action: {
                viewModel.fetchNewsSummary()
            }) {
                Text("Refresh News Summary")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Latest News")
        .onAppear {
            viewModel.fetchNewsSummary()
        }
    }
}

struct NewsView_Previews: PreviewProvider {
    static var previews: some View {
        NewsView()
    }
}
