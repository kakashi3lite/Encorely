import SwiftUI

struct PodcastEpisodeRow: View {
    let title: String
    let podcast: String
    let duration: Int
    let aiService: AIIntegrationService
    
    @State private var isPlaying = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Episode number circle
            Button(action: {
                isPlaying.toggle()
                aiService.trackInteraction(type: "podcast_episode_\(isPlaying ? "play" : "pause")")
                hapticFeedback(style: .light)
            }) {
                ZStack {
                    Circle()
                        .fill(isPlaying ? aiService.moodEngine.currentMood.color : Color(.systemGray5))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isPlaying ? .white : .primary)
                }
            }
            
            // Episode info
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                HStack {
                    Text(podcast)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(duration) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Download button
            Button(action: {
                aiService.trackInteraction(type: "podcast_episode_download_tapped")
                hapticFeedback(style: .light)
            }) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .padding(.trailing, 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
