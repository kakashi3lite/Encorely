import SwiftUI

struct ReorderableQueueItem: View {
    let title: String
    let subtitle: String?
    let artwork: Image?
    let isPlaying: Bool
    let onTap: (() -> Void)?
    let onDelete: (() -> Void)?

    init(
        title: String,
        subtitle: String? = nil,
        artwork: Image? = nil,
        isPlaying: Bool = false,
        onTap: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.artwork = artwork
        self.isPlaying = isPlaying
        self.onTap = onTap
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .accessibilityLabel("Drag to reorder")
                .padding(.trailing, 4)
                .onLongPressGesture(minimumDuration: 0.1) {
                    HapticFeedback.play(.medium)
                }

            // Artwork
            Group {
                if let artwork {
                    artwork
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary))
                }
            }
            .frame(width: 40, height: 40)
            .cornerRadius(4)

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(isPlaying ? .accentColor : .primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Playing indicator
            if isPlaying {
                Image(systemName: "soundwave.3.fill")
                    .foregroundColor(.accentColor)
                    .accessibilityLabel("Currently playing")
            }

            // Delete button
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove from queue")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isPlaying ? "Playing: " : "")\(title)\(subtitle != nil ? ", \(subtitle!)" : "")")
    }
}
