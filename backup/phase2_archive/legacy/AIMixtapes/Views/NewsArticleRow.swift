import SwiftUI

struct NewsArticleRow: View {
    let title: String
    let source: String
    let timeAgo: Int // hours
    let hasImage: Bool
    let aiService: AIIntegrationService

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // Article content
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)

                HStack {
                    Text(source)
                        .font(.caption)
                        .foregroundColor(aiService.moodEngine.currentMood.color)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(timeAgo)h ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    Button(action: {
                        aiService.trackInteraction(type: "news_article_share")
                        hapticFeedback(style: .light)
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                            Text("Share")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }

                    Button(action: {
                        aiService.trackInteraction(type: "news_article_save")
                        hapticFeedback(style: .light)
                    }) {
                        HStack {
                            Image(systemName: "bookmark")
                                .font(.caption)
                            Text("Save")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }

            Spacer()

            // Article image (if available)
            if hasImage {
                RoundedRectangle(cornerRadius: 8)
                    .fill(aiService.moodEngine.currentMood.color.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "newspaper")
                            .font(.system(size: 24))
                            .foregroundColor(aiService.moodEngine.currentMood.color.opacity(0.8)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1))
    }

    private func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
