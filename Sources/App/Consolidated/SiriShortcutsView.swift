import Intents
import IntentsUI
import SwiftUI

struct SiriShortcutsView: View {
    // MARK: - Properties

    var aiService: AIIntegrationService
    @Environment(\.presentationMode) var presentationMode
    @State private var shortcuts: [VoiceShortcut] = []
    @State private var showingAddShortcut = false
    @State private var selectedShortcut: VoiceShortcut?
    @State private var showingPermissionAlert = false
    @State private var isLoading = true

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Status banner
                    StatusBanner(isEnabled: aiService.siriIntegrationEnabled)

                    if isLoading {
                        ProgressView("Loading shortcuts...")
                            .padding()
                    } else {
                        // Available shortcuts
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Voice Commands")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(shortcuts) { shortcut in
                                ShortcutRow(
                                    shortcut: shortcut,
                                    onTap: { selectedShortcut = shortcut },
                                    onDelete: { deleteShortcut(shortcut) }
                                )
                            }

                            // Add new shortcut button
                            Button(action: { showingAddShortcut = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("Add New Command")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 2)
                                        .background(Color.blue.opacity(0.05))
                                )
                            }
                            .padding(.horizontal)
                            .disabled(!aiService.siriIntegrationEnabled)
                        }

                        // Usage examples
                        ExamplesSection()
                            .padding(.top)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Siri Integration")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .sheet(isPresented: $showingAddShortcut) {
                AddShortcutView(
                    aiService: aiService,
                    onAdd: { shortcut in
                        shortcuts.append(shortcut)
                        showingAddShortcut = false
                    }
                )
            }
            .sheet(item: $selectedShortcut) { shortcut in
                ShortcutDetailView(shortcut: shortcut)
            }
            .alert(isPresented: $showingPermissionAlert) {
                Alert(
                    title: Text("Enable Siri"),
                    message: Text("Please enable Siri in Settings to use voice commands."),
                    primaryButton: .default(Text("Open Settings"), action: openSettings),
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                loadShortcuts()
            }
        }
    }

    // MARK: - Supporting Views

    struct StatusBanner: View {
        let isEnabled: Bool

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isEnabled ? .green : .orange)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isEnabled ? "Siri Integration Active" : "Siri Integration Disabled")
                        .font(.headline)
                    Text(isEnabled ? "Voice commands are ready to use" :
                        "Enable Siri in Settings to use voice commands")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            .padding(.horizontal)
        }
    }

    struct ShortcutRow: View {
        let shortcut: VoiceShortcut
        let onTap: () -> Void
        let onDelete: () -> Void

        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 16) {
                    // Icon
                    Image(systemName: shortcut.icon)
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 32)

                    // Command info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shortcut.phrase)
                            .fontWeight(.medium)
                        Text(shortcut.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Delete button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
        }
    }

    struct ExamplesSection: View {
        let examples = [
            ("Play happy music", "Creates and plays a mixtape matching your happy mood"),
            ("Create a relaxing mixtape", "Generates a new mixtape with calm, soothing tracks"),
            ("Analyze current song", "Shows detailed audio analysis of the playing track"),
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Example Commands")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(examples, id: \.0) { example in
                    HStack(spacing: 12) {
                        Image(systemName: "quote.bubble")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(example.0)
                                .fontWeight(.medium)
                            Text(example.1)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helper Methods

    private func loadShortcuts() {
        isLoading = true

        // Simulate loading shortcuts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shortcuts = [
                VoiceShortcut(
                    phrase: "Play happy music",
                    description: "Creates and plays an upbeat mixtape",
                    icon: "face.smiling"
                ),
                VoiceShortcut(
                    phrase: "Create a relaxing mixtape",
                    description: "Generates a calm, soothing playlist",
                    icon: "leaf"
                ),
                VoiceShortcut(
                    phrase: "Analyze current song",
                    description: "Shows detailed audio analysis",
                    icon: "waveform"
                ),
            ]
            isLoading = false
        }
    }

    private func deleteShortcut(_ shortcut: VoiceShortcut) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts.remove(at: index)
            aiService.trackInteraction(type: "delete_shortcut")
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Types

struct VoiceShortcut: Identifiable {
    let id = UUID()
    let phrase: String
    let description: String
    let icon: String
}

struct AddShortcutView: View {
    var aiService: AIIntegrationService
    var onAdd: (VoiceShortcut) -> Void

    @Environment(\.presentationMode) var presentationMode
    @State private var phrase = ""
    @State private var description = ""
    @State private var selectedIcon = "waveform"

    private let availableIcons = [
        "waveform", "music.note", "leaf", "face.smiling",
        "heart.fill", "star.fill", "bolt.fill", "moon.fill",
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Command Details")) {
                    TextField("Voice Command", text: $phrase)
                    TextField("Description", text: $description)
                }

                Section(header: Text("Icon")) {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 44)),
                    ], spacing: 16) {
                        ForEach(availableIcons, id: \.self) { icon in
                            IconButton(
                                icon: icon,
                                isSelected: selectedIcon == icon,
                                action: { selectedIcon = icon }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Command")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Add") {
                    let shortcut = VoiceShortcut(
                        phrase: phrase,
                        description: description,
                        icon: selectedIcon
                    )
                    onAdd(shortcut)
                    aiService.trackInteraction(type: "add_shortcut")
                }
                .disabled(phrase.isEmpty || description.isEmpty)
            )
        }
    }
}

struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isSelected ? .white : .blue)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                )
        }
    }
}

struct ShortcutDetailView: View {
    let shortcut: VoiceShortcut
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Icon
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: shortcut.icon)
                            .font(.system(size: 36))
                            .foregroundColor(.blue)
                    )

                // Command details
                VStack(spacing: 8) {
                    Text(shortcut.phrase)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(shortcut.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Usage instructions
                VStack(alignment: .leading, spacing: 16) {
                    Text("How to Use")
                        .font(.headline)

                    InstructionRow(
                        number: 1,
                        text: "Say 'Hey Siri' to activate"
                    )

                    InstructionRow(
                        number: 2,
                        text: "Say '\(shortcut.phrase)'"
                    )

                    InstructionRow(
                        number: 3,
                        text: "Mixtapes will handle the rest"
                    )
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                Spacer()
            }
            .padding()
            .navigationTitle("Command Details")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.blue)
                .frame(width: 24, height: 24)
                .overlay(
                    Text("\(number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )

            Text(text)
                .font(.body)

            Spacer()
        }
    }
}

// MARK: - Preview

struct SiriShortcutsView_Previews: PreviewProvider {
    static var previews: some View {
        SiriShortcutsView(aiService: AIIntegrationService())
    }
}
