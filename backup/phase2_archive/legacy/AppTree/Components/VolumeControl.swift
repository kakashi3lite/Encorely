import SwiftUI

struct VolumeControl: View {
    @Binding var volume: Double
    let showLabel: Bool
    let size: CGFloat
    let onChanged: ((Double) -> Void)?

    init(
        volume: Binding<Double>,
        showLabel: Bool = true,
        size: CGFloat = 24,
        onChanged: ((Double) -> Void)? = nil
    ) {
        _volume = volume
        self.showLabel = showLabel
        self.size = size
        self.onChanged = onChanged
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: volumeIcon)
                .font(.system(size: size))
                .foregroundColor(.secondary)
                .frame(width: size)
                .accessibilityLabel(volumeLabel)

            Slider(
                value: $volume,
                in: 0 ... 1,
                step: 0.05
            ) { isEditing in
                if !isEditing {
                    onChanged?(volume)
                }
            }
            .frame(width: size * 4)

            if showLabel {
                Text("\(Int(volume * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var volumeIcon: String {
        switch volume {
        case 0:
            "speaker.slash.fill"
        case 0 ..< 0.3:
            "speaker.wave.1.fill"
        case 0.3 ..< 0.7:
            "speaker.wave.2.fill"
        default:
            "speaker.wave.3.fill"
        }
    }

    private var volumeLabel: String {
        switch volume {
        case 0:
            "Muted"
        case 0 ..< 0.3:
            "Low volume"
        case 0.3 ..< 0.7:
            "Medium volume"
        default:
            "High volume"
        }
    }
}
