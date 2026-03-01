import SwiftUI

/// Displays all personality types and highlights the current one.
struct PersonalityView: View {
    @Environment(PersonalityEngine.self) private var personalityEngine

    var body: some View {
        ForEach(PersonalityType.allCases) { type in
            HStack(spacing: 12) {
                Circle()
                    .fill(type.themeColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.subheadline.weight(
                            type == personalityEngine.currentPersonality ? .bold : .regular
                        ))
                    Text(type.typeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if type == personalityEngine.currentPersonality {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(type.themeColor)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(type.rawValue), \(type.typeDescription)" +
                (type == personalityEngine.currentPersonality ? ", current" : "")
            )
        }
    }
}
