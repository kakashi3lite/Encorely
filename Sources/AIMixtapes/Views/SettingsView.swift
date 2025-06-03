import SwiftUI

struct SettingsView: View {
    var aiService: AIIntegrationService
    
    @AppStorage("useAudioAnalysis") private var useAudioAnalysis = true
    @AppStorage("useFacialExpressions") private var useFacialExpressions = true
    @AppStorage("useSiriIntegration") private var useSiriIntegration = true
    
    @State private var showPersonalitySettings = false
    @State private var showMoodSettings = false
    @State private var showSiriSettings = false
    @State private var showingClearDataAlert = false
    
    var body: some View {
        Form {
            // AI Features section
            Section {
                Toggle("Audio Analysis", isOn: $useAudioAnalysis)
                    .onChange(of: useAudioAnalysis) { _ in
                        aiService.trackInteraction(type: "setting_audio_analysis_toggle")
                    }
                
                Toggle("Facial Expression Detection", isOn: $useFacialExpressions)
                    .onChange(of: useFacialExpressions) { _ in
                        aiService.trackInteraction(type: "setting_facial_expressions_toggle")
                    }
                
                Toggle("Siri Integration", isOn: $useSiriIntegration)
                    .onChange(of: useSiriIntegration) { _ in
                        aiService.trackInteraction(type: "setting_siri_integration_toggle")
                    }
            } header: {
                Label("AI Features", systemImage: "brain")
            }
            
            // Personality & Mood section
            Section {
                NavigationLink(destination: PersonalityView(personalityEngine: aiService.personalityEngine)) {
                    HStack {
                        Label(
                            title: { Text("Music Personality") },
                            icon: { Image(systemName: aiService.personalityEngine.currentPersonality.icon) }
                        )
                        Spacer()
                        Text(aiService.personalityEngine.currentPersonality.rawValue)
                            .foregroundColor(.secondary)
                    }
                }
                
                NavigationLink(destination: MoodView(moodEngine: aiService.moodEngine)) {
                    HStack {
                        Label(
                            title: { Text("Default Mood") },
                            icon: { Image(systemName: aiService.moodEngine.currentMood.systemIcon) }
                        )
                        Spacer()
                        Text(aiService.moodEngine.currentMood.rawValue)
                            .foregroundColor(aiService.moodEngine.currentMood.color)
                    }
                }
            } header: {
                Label("Personalization", systemImage: "person.fill")
            }
            
            // Performance section
            Section {
                NavigationLink(destination: AudioSettingsView()) {
                    Label("Audio Processing", systemImage: "waveform")
                }
                
                NavigationLink(destination: StorageSettingsView()) {
                    Label("Storage & Caching", systemImage: "internaldrive")
                }
            } header: {
                Label("Performance", systemImage: "gauge")
            }
            
            // Integrations section
            Section {
                NavigationLink(destination: SiriShortcutsView(aiService: aiService)) {
                    Label("Manage Siri Shortcuts", systemImage: "mic.circle")
                }
                
                NavigationLink(destination: NotificationSettingsView()) {
                    Label("Notifications", systemImage: "bell")
                }
            } header: {
                Label("Integrations", systemImage: "link")
            }
            
            // Data section
            Section {
                Button(role: .destructive) {
                    showingClearDataAlert = true
                } label: {
                    Label("Clear App Data", systemImage: "trash")
                }
            } header: {
                Label("Data", systemImage: "externaldrive")
            }
            
            // About section
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                NavigationLink("Privacy Policy") {
                    PrivacyPolicyView()
                }
                
                NavigationLink("Terms of Service") {
                    TermsOfServiceView()
                }
                
                HStack {
                    Text("Developer")
                    Spacer()
                    Text("Swanand Tanavade")
                        .foregroundColor(.secondary)
                }
            } header: {
                Label("About", systemImage: "info.circle")
            }
        }
        .navigationTitle("Settings")
        .alert("Clear App Data", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All Data", role: .destructive) {
                clearAppData()
            }
        } message: {
            Text("This will remove all your mixtapes, settings, and personalization data. This action cannot be undone.")
        }
    }
    
    private func clearAppData() {
        // Implement data clearing
        aiService.trackInteraction(type: "clear_app_data")
    }
}

struct AudioSettingsView: View {
    @AppStorage("audioQuality") private var audioQuality = "High"
    @AppStorage("enableEqualizer") private var enableEqualizer = true
    
    var body: some View {
        Form {
            Section(header: Text("Audio Quality")) {
                Picker("Quality", selection: $audioQuality) {
                    Text("High").tag("High")
                    Text("Medium").tag("Medium")
                    Text("Low").tag("Low")
                }
            }
            
            Section(header: Text("Equalizer")) {
                Toggle("Enable Equalizer", isOn: $enableEqualizer)
            }
        }
        .navigationTitle("Audio Settings")
    }
}

struct StorageSettingsView: View {
    @State private var cacheSize = "234 MB"
    @State private var clearingCache = false
    
    var body: some View {
        Form {
            Section(header: Text("Cache")) {
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text(cacheSize)
                        .foregroundColor(.secondary)
                }
                
                Button(action: clearCache) {
                    if clearingCache {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Clear Cache")
                    }
                }
                .disabled(clearingCache)
            }
        }
        .navigationTitle("Storage Settings")
    }
    
    private func clearCache() {
        clearingCache = true
        // Implement cache clearing
        clearingCache = false
    }
}

struct NotificationSettingsView: View {
    @AppStorage("notifyNewMixtapes") private var notifyNewMixtapes = true
    @AppStorage("notifyMoodChanges") private var notifyMoodChanges = true
    
    var body: some View {
        Form {
            Toggle("New AI Mixtapes", isOn: $notifyNewMixtapes)
            Toggle("Mood Changes", isOn: $notifyMoodChanges)
        }
        .navigationTitle("Notifications")
    }
}