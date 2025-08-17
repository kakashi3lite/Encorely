import SwiftUI

struct MoodCard: View {
    let mood: MoodType
    let isAnalyzing: Bool
    let isSelected: Bool

    init(
        mood: MoodType,
        isAnalyzing: Bool = false,
        isSelected: Bool = false
    ) {
        self.mood = mood
        self.isAnalyzing = isAnalyzing
        self.isSelected = isSelected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Mood")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()

                if isAnalyzing {
                    AILoadingView(message: "Analyzing mood")
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: mood.systemIcon)
                        .foregroundColor(mood.color)
                        .accessibilityLabel(mood.accessibilityLabel)
                }
            }

            Text(mood.rawValue)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: isSelected ? mood.color.opacity(0.3) : Color.black.opacity(0.1),
                        radius: isSelected ? 12 : 8))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? mood.color : Color.clear, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isAnalyzing ? "Analyzing mood" : "Current mood: \(mood.rawValue)")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

extension MoodType {
    var accessibilityLabel: String {
        switch self {
        case .energetic:
            "Energetic mood"
        case .relaxed:
            "Relaxed mood"
        case .happy:
            "Happy mood"
        case .melancholic:
            "Melancholic mood"
        case .focused:
            "Focused mood"
        case .angry:
            "Angry mood"
        }
    }
}
