import SwiftUI

struct AudioProcessingBanner: View {
    @ObservedObject var analysisService: AudioAnalysisService

    @State private var showBanner = false
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            if showBanner {
                banner
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .audioServicePaused)) { notification in
            if let error = notification.object as? AudioAnalysisError {
                errorMessage = error.localizedDescription
                withAnimation {
                    showBanner = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .audioServiceResumed)) { _ in
            withAnimation {
                showBanner = false
                errorMessage = nil
            }
        }
    }

    private var banner: some View {
        VStack(spacing: 8) {
            if let error = errorMessage {
                errorBanner(message: error)
            } else if analysisService.isAnalyzing {
                processingBanner
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(bannerBackground)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var processingBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))

            VStack(alignment: .leading) {
                Text("Analyzing Audio")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("\(Int(analysisService.progress * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            Button(action: {
                withAnimation {
                    showBanner = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()

            Button(action: {
                withAnimation {
                    showBanner = false
                    errorMessage = nil
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var bannerBackground: some View {
        Group {
            if errorMessage != nil {
                Color.red
            } else {
                Color.blue
            }
        }
        .opacity(0.9)
    }
}
