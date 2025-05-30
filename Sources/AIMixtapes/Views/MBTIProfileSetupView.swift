import SwiftUI

struct MBTIProfileSetupView: View {
    @StateObject private var viewModel = MBTIProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // MBTI Dimensions
                Section(header: Text("Your MBTI Profile")) {
                    MBTIDimensionSlider(
                        value: $viewModel.extraversion,
                        title: "Extraversion - Introversion",
                        leftLabel: "Introverted",
                        rightLabel: "Extroverted"
                    )
                    
                    MBTIDimensionSlider(
                        value: $viewModel.sensing,
                        title: "Sensing - Intuition",
                        leftLabel: "Intuitive",
                        rightLabel: "Sensing"
                    )
                    
                    MBTIDimensionSlider(
                        value: $viewModel.thinking,
                        title: "Thinking - Feeling",
                        leftLabel: "Feeling",
                        rightLabel: "Thinking"
                    )
                    
                    MBTIDimensionSlider(
                        value: $viewModel.judging,
                        title: "Judging - Perceiving",
                        leftLabel: "Perceiving",
                        rightLabel: "Judging"
                    )
                }
                
                // Preview Section
                Section(header: Text("Profile Summary")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Type: \(viewModel.mbtiType)")
                            .font(.headline)
                        
                        Text("Musical Preferences")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        PreferenceProgressView(
                            title: "Energy",
                            value: viewModel.predictedPreferences.energy
                        )
                        
                        PreferenceProgressView(
                            title: "Tempo",
                            value: (viewModel.predictedPreferences.tempo - 60) / 120
                        )
                        
                        PreferenceProgressView(
                            title: "Complexity",
                            value: viewModel.predictedPreferences.complexity
                        )
                        
                        PreferenceProgressView(
                            title: "Structure",
                            value: viewModel.predictedPreferences.structure
                        )
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("MBTI Profile Setup")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveProfile()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct MBTIDimensionSlider: View {
    @Binding var value: Float
    let title: String
    let leftLabel: String
    let rightLabel: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack {
                Text(leftLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: $value, in: 0...1)
                
                Text(rightLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PreferenceProgressView: View {
    let title: String
    let value: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.0f%%", value * 100))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: value)
                .tint(Color.accentColor)
        }
    }
}

// MARK: - Preview

struct MBTIProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        MBTIProfileSetupView()
    }
}
