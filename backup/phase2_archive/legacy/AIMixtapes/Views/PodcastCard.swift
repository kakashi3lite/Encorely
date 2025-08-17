import SwiftUI

struct PodcastCard: View {
    let title: String
    let host: String
    let coverImage: String
    let mood: Mood

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Podcast cover image with gradient overlay
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(mood.color.opacity(0.2))
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 32))
                            .foregroundColor(mood.color.opacity(0.6)))

                // Play button
                Circle()
                    .fill(mood.color)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white))
                    .offset(y: 18)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .frame(height: 140)

            // Podcast info
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)

                Text(host)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Episode count and rating
                HStack {
                    Text("42 episodes")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(mood.color)
                        Text("4.8")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 16)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4))
    }
}
