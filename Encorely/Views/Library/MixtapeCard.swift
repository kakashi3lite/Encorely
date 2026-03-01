import SwiftUI

/// A visual card for displaying a mixtape in the grid layout.
struct MixtapeCard: View {
    let mixtape: Mixtape

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mood-colored artwork placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(mixtape.dominantMood.color.gradient)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: mixtape.dominantMood.systemIcon)
                            .font(.system(size: 32))
                            .foregroundStyle(.white)

                        if mixtape.isAIGenerated {
                            Label("AI", systemImage: "sparkles")
                                .font(.caption2.bold())
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                }

            // Title and metadata
            Text(mixtape.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text("\(mixtape.songCount) songs")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mixtape.title), \(mixtape.songCount) songs")
    }
}
