import SwiftUI

struct VoiceCommandView: View {
    @StateObject private var voiceService = VoiceCommandService()
    @State private var showingPermissionAlert = false
    @State private var permissionError: Error?

    var body: some View {
        VStack(spacing: 16) {
            // Voice Status
            HStack {
                Image(systemName: voiceService.isListening ? "waveform" : "mic")
                    .font(.title)
                    .foregroundColor(voiceService.isListening ? .blue : .secondary)
                    .animation(.easeInOut, value: voiceService.isListening)

                Text(voiceService.isListening ? "Listening..." : "Tap to speak")
                    .font(.headline)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground)))
            .onTapGesture {
                toggleListening()
            }

            // Transcript Display
            if !voiceService.interimTranscript.isEmpty {
                Text(voiceService.interimTranscript)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemBackground)))
            }

            // Command Examples
            VStack(alignment: .leading, spacing: 12) {
                Text("Try saying:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                CommandExampleView(
                    icon: "beats.headphones",
                    text: "\"Play something energetic\""
                )

                CommandExampleView(
                    icon: "moon.stars",
                    text: "\"I need relaxing music\""
                )

                CommandExampleView(
                    icon: "brain.head.profile",
                    text: "\"Music for focusing\""
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground)))
        }
        .padding()
        .alert("Speech Recognition Permission",
               isPresented: $showingPermissionAlert,
               presenting: permissionError)
        { _ in
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private func toggleListening() {
        Task {
            do {
                if voiceService.isListening {
                    voiceService.stopListening()
                } else {
                    try await voiceService.requestAuthorization()
                    voiceService.startListening()
                }
            } catch {
                permissionError = error
                showingPermissionAlert = true
            }
        }
    }
}

struct CommandExampleView: View {
    let icon: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline)
        } icon: {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
        }
    }
}

#Preview {
    VoiceCommandView()
}
