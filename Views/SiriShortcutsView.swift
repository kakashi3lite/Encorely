import SwiftUI
import Intents
import IntentsUI

struct SiriShortcutsView: View {
    @ObservedObject var aiService: AIIntegrationService
    @Environment(\.presentationMode) var presentationMode
    @State private var shortcuts: [INVoiceShortcut] = []
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Available Commands")) {
                    // Play Mood Command
                    ForEach(Mood.allCases, id: \.self) { mood in
                        SiriShortcutRow(
                            title: "Play \(mood.rawValue) Music",
                            subtitle: "Start playing music matching your \(mood.rawValue.lowercased()) mood",
                            icon: mood.systemIcon,
                            color: mood.color
                        ) {
                            addVoiceShortcut(for: mood)
                        }
                    }
                    
                    // Create Mixtape Command
                    SiriShortcutRow(
                        title: "Create AI Mixtape",
                        subtitle: "Generate a new AI-powered mixtape",
                        icon: "waveform.path.badge.plus",
                        color: .purple
                    ) {
                        addCreateMixtapeShortcut()
                    }
                    
                    // Analyze Current Song Command
                    SiriShortcutRow(
                        title: "Analyze Current Song",
                        subtitle: "Analyze the mood and features of the current song",
                        icon: "waveform.circle",
                        color: .blue
                    ) {
                        addAnalyzeShortcut()
                    }
                }
                
                if !shortcuts.isEmpty {
                    Section(header: Text("Your Shortcuts")) {
                        ForEach(shortcuts, id: \.identifier) { shortcut in
                            HStack {
                                Text(shortcut.invocationPhrase)
                                Spacer()
                                Button(action: {
                                    deleteShortcut(shortcut)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Siri Shortcuts")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear(perform: loadShortcuts)
        }
    }
    
    private func loadShortcuts() {
        INVoiceShortcutCenter.shared.getAllVoiceShortcuts { shortcuts, error in
            if let shortcuts = shortcuts {
                DispatchQueue.main.async {
                    self.shortcuts = shortcuts
                }
            }
        }
    }
    
    private func addVoiceShortcut(for mood: Mood) {
        let intent = PlayMoodIntent()
        intent.mood = MoodParameter(identifier: mood.rawValue, display: mood.rawValue)
        intent.suggestedInvocationPhrase = "Play \(mood.rawValue.lowercased()) music"
        
        presentAddVoiceShortcutUI(for: intent)
    }
    
    private func addCreateMixtapeShortcut() {
        let intent = CreateMixtapeIntent()
        intent.suggestedInvocationPhrase = "Create a new mixtape"
        
        presentAddVoiceShortcutUI(for: intent)
    }
    
    private func addAnalyzeShortcut() {
        let intent = AnalyzeCurrentSongIntent()
        intent.suggestedInvocationPhrase = "Analyze this song"
        
        presentAddVoiceShortcutUI(for: intent)
    }
    
    private func presentAddVoiceShortcutUI(for intent: INIntent) {
        let shortcut = INShortcut(intent: intent)
        let viewController = INUIAddVoiceShortcutViewController(shortcut: shortcut)
        viewController.delegate = ShortcutDelegate(completion: loadShortcuts)
        
        // Present the view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(viewController, animated: true)
        }
    }
    
    private func deleteShortcut(_ shortcut: INVoiceShortcut) {
        INVoiceShortcutCenter.shared.deleteVoiceShortcut(shortcut) { error in
            if error == nil {
                DispatchQueue.main.async {
                    loadShortcuts()
                }
            }
        }
    }
}

struct SiriShortcutRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 4)
        }
    }
}

class ShortcutDelegate: NSObject, INUIAddVoiceShortcutViewControllerDelegate {
    let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
    }
    
    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?) {
        controller.dismiss(animated: true) {
            self.completion()
        }
    }
    
    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        controller.dismiss(animated: true)
    }
}