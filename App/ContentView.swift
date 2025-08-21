import SwiftUI
import GlassUI
import AudioKitEncorely

struct ContentView: View {
    @StateObject private var audioManager = AudioSessionManager()
    @State private var isRecording = false
    @State private var audioLevel: Float = 0.0
    @State private var selectedTab: Tab = .home
    @State private var showingError = false
    @State private var errorMessage = ""
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    
    enum Tab: String, CaseIterable {
        case home = "Home"
        case recorder = "Recorder"
        case visualizer = "Visualizer"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .recorder: return "mic.fill"
            case .visualizer: return "waveform"
            case .settings: return "gear"
            }
        }
    }
    
    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }
    
    private var adaptiveSpacing: CGFloat {
        isCompactLayout ? 16 : 24
    }
    
    private var adaptivePadding: CGFloat {
        isCompactLayout ? 16 : 24
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()
                
                if isCompactLayout {
                    compactLayout
                } else {
                    regularLayout
                }
            }
        }
        .alert("Audio Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            setupAudio()
        }
        .onReceive(audioManager.$isInterrupted) { interrupted in
            if interrupted && isRecording {
                stopRecording()
            }
        }
    }
    
    @ViewBuilder
    private var backgroundGradient: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var backgroundColors: [Color] {
        switch colorScheme {
        case .dark:
            return [Color.purple.opacity(0.3), Color.blue.opacity(0.2)]
        case .light:
            return [Color.blue.opacity(0.15), Color.purple.opacity(0.15)]
        @unknown default:
            return [Color.blue.opacity(0.25), Color.purple.opacity(0.25)]
        }
    }
    
    @ViewBuilder
    private var compactLayout: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                    }
                    .tag(tab)
            }
        }
        .tint(.primary)
    }
    
    @ViewBuilder
    private var regularLayout: some View {
        HStack(spacing: 0) {
            NavigationSidebar(selectedTab: $selectedTab)
                .frame(width: 280)
            
            Divider()
            
            tabContent(for: selectedTab)
                .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        ScrollView {
            LazyVStack(spacing: adaptiveSpacing) {
                headerView
                
                switch tab {
                case .home:
                    homeContent
                case .recorder:
                    recorderContent
                case .visualizer:
                    visualizerContent
                case .settings:
                    settingsContent
                }
            }
            .padding(adaptivePadding)
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Encorely")
                .font(isCompactLayout ? .largeTitle : .system(size: 48, weight: .bold, design: .rounded))
                .fontWeight(.semibold)
            
            if !isCompactLayout {
                Text("Professional Audio Suite")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, isCompactLayout ? 8 : 16)
    }
    
    @ViewBuilder
    private var homeContent: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "waveform.badge.checkmark")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Audio Status")
                            .font(.headline)
                        Text(audioManager.isActive ? "Active" : "Inactive")
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(audioManager.isActive ? .green : .red)
                        .frame(width: 12, height: 12)
                }
                
                if !audioManager.currentRoute.isEmpty {
                    Divider()
                    
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(.secondary)
                        Text("Route: \(audioManager.currentRoute)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        
        quickActionsCard
        
        featuresCard
    }
    
    @ViewBuilder
    private var quickActionsCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                Text("Quick Actions")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: isCompactLayout ? 2 : 3), spacing: 12) {
                    ActionButton(
                        title: "Test Audio",
                        icon: "speaker.3.fill",
                        action: testAudio
                    )
                    
                    ActionButton(
                        title: "Record",
                        icon: "record.circle.fill",
                        action: { selectedTab = .recorder }
                    )
                    
                    ActionButton(
                        title: "Visualize",
                        icon: "waveform.circle.fill",
                        action: { selectedTab = .visualizer }
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var featuresCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Features")
                    .font(.headline)
                
                FeatureRow(icon: "mic.fill", title: "Professional Recording", description: "High-quality audio capture with real-time monitoring")
                FeatureRow(icon: "waveform", title: "Live Visualization", description: "Real-time audio waveform and spectrum analysis")
                FeatureRow(icon: "slider.horizontal.3", title: "Audio Processing", description: "Advanced DSP with RMS analysis and filtering")
                FeatureRow(icon: "accessibility", title: "Accessibility", description: "Full VoiceOver support and accessibility features")
            }
        }
    }
    
    @ViewBuilder
    private var recorderContent: some View {
        GlassCard {
            VStack(spacing: 20) {
                Text("Audio Recorder")
                    .font(.title2.weight(.semibold))
                
                // Audio Level Meter
                VStack(spacing: 8) {
                    Text("Level")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    AudioLevelMeter(level: audioLevel)
                        .frame(height: 8)
                }
                
                // Record Button
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? .red : .blue)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
                .scaleEffect(isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isRecording)
                
                Text(isRecording ? "Recording..." : "Tap to Record")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var visualizerContent: some View {
        GlassCard {
            VStack(spacing: 16) {
                Text("Audio Visualizer")
                    .font(.title2.weight(.semibold))
                
                // Placeholder for visualizer
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "waveform")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Visualizer Coming Soon")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    )
            }
        }
    }
    
    @ViewBuilder
    private var settingsContent: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                
                SettingsRow(
                    title: "Audio Session",
                    subtitle: audioManager.isActive ? "Active" : "Inactive",
                    icon: "speaker.wave.3.fill"
                )
                
                SettingsRow(
                    title: "Current Route",
                    subtitle: audioManager.currentRoute.isEmpty ? "None" : audioManager.currentRoute,
                    icon: "audio.output.and.input"
                )
                
                SettingsRow(
                    title: "Interruption Status",
                    subtitle: audioManager.isInterrupted ? "Interrupted" : "Normal",
                    icon: "exclamationmark.triangle.fill"
                )
                
                SettingsRow(
                    title: "Version",
                    subtitle: "1.0.0",
                    icon: "info.circle.fill"
                )
            }
        }
    }
    
    private func setupAudio() {
        do {
            try audioManager.configureAndActivate(category: .playAndRecord)
        } catch {
            errorMessage = "Failed to setup audio: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func testAudio() {
        // Generate test samples for RMS calculation
        let testSamples: [Float] = (0..<1024).map { i in
            sin(Float(i) * 0.1) * 0.5
        }
        
        let rmsValue = DSP.rms(testSamples)
        audioLevel = rmsValue
        
        // Animate the level back down
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 1.0)) {
                audioLevel = 0.0
            }
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        do {
            try audioManager.configureAndActivate(category: .record)
            isRecording = true
            
            // Simulate audio level updates
            startAudioLevelUpdates()
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func stopRecording() {
        isRecording = false
        audioLevel = 0.0
        
        do {
            try audioManager.configureAndActivate(category: .playback)
        } catch {
            errorMessage = "Failed to stop recording: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func startAudioLevelUpdates() {
        guard isRecording else { return }
        
        // Simulate realistic audio levels
        let randomLevel = Float.random(in: 0.1...0.8)
        withAnimation(.easeInOut(duration: 0.1)) {
            audioLevel = randomLevel
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startAudioLevelUpdates()
        }
    }
}

#Preview {
    ContentView()
}
