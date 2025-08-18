//
//  AudioProcessingConfigView.swift
//  AI-Mixtapes
//  Created by AI Assistant on 05/23/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import SwiftUI

struct AudioProcessingConfigView: View {
    @ObservedObject private var config = AudioProcessingConfiguration.shared
    @State private var showingErrorAlert = false
    @State private var errorMessages: [String] = []
    @State private var selectedPreset: ConfigurationPreset?

    var body: some View {
        Form {
            // Presets Section
            Section(header: Text("Configuration Presets")) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ConfigurationPreset.allCases, id: \.self) { preset in
                            VStack {
                                Button(action: {
                                    selectedPreset = preset
                                }) {
                                    VStack {
                                        Image(systemName: iconForPreset(preset))
                                            .font(.largeTitle)
                                            .foregroundColor(.accentColor)
                                        Text(preset.displayName)
                                            .font(.caption)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                selectedPreset == preset ? Color.accentColor : Color.gray,
                                                lineWidth: selectedPreset == preset ? 2 : 1
                                            )
                                    )
                                }

                                if selectedPreset == preset {
                                    Text(preset.description)
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)

                                    Button("Apply") {
                                        config.applyPreset(preset)
                                    }
                                    .buttonStyle(.bordered)
                                    .padding(.top, 4)
                                }
                            }
                            .frame(width: 150)
                            .animation(.default, value: selectedPreset)
                        }
                    }
                    .padding(.vertical)
                }
            }

            // Audio Engine Settings
            Section(header: Text("Audio Engine")) {
                VStack(alignment: .leading) {
                    Text("Sample Rate: \(Int(config.sampleRate)) Hz")
                    Slider(value: $config.sampleRate, in: 22050 ... 96000, step: 100)
                }

                VStack(alignment: .leading) {
                    Text("Buffer Size: \(config.bufferSize) samples")
                    Slider(value: Binding(
                        get: { Double(config.bufferSize) },
                        set: { config.bufferSize = UInt32($0) }
                    ), in: 256 ... 8192, step: 256)
                }
            }

            // Performance Settings
            Section(header: Text("Performance")) {
                VStack(alignment: .leading) {
                    Text("Max Processing Latency: \(Int(config.maxProcessingLatency * 1000)) ms")
                    Slider(value: $config.maxProcessingLatency, in: 0.01 ... 0.5, step: 0.01)
                }

                VStack(alignment: .leading) {
                    let memoryMB = Double(config.maxMemoryUsage) / (1024.0 * 1024.0)
                    Text("Max Memory Usage: \(Int(memoryMB)) MB")
                    Slider(value: Binding(
                        get: { Double(config.maxMemoryUsage) / (1024.0 * 1024.0) },
                        set: { config.maxMemoryUsage = UInt64($0 * 1024.0 * 1024.0) }
                    ), in: 10 ... 200, step: 5)
                }

                VStack(alignment: .leading) {
                    Text("Target FPS: \(Int(config.targetFPS))")
                    Slider(value: $config.targetFPS, in: 10 ... 60, step: 5)
                }

                Toggle("Enable Performance Monitoring", isOn: $config.enablePerformanceMonitoring)
            }

            // Analysis Settings
            Section(header: Text("Analysis")) {
                Toggle("Audio Analysis Enabled", isOn: $config.analysisEnabled)

                if config.analysisEnabled {
                    Toggle("Real-time Analysis", isOn: $config.realTimeAnalysisEnabled)
                    Toggle("Mood Detection", isOn: $config.moodDetectionEnabled)
                    Toggle("Spectral Analysis", isOn: $config.spectralAnalysisEnabled)
                    Toggle("Tempo Detection", isOn: $config.tempoDetectionEnabled)

                    Picker("Audio Quality", selection: $config.audioQuality) {
                        ForEach(AudioQuality.allCases, id: \.self) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }

                    Picker("Window Function", selection: $config.windowFunction) {
                        ForEach(WindowFunction.allCases, id: \.self) { function in
                            Text(function.displayName).tag(function)
                        }
                    }
                }
            }

            // Mood Detection Settings
            if config.moodDetectionEnabled {
                Section(header: Text("Mood Detection")) {
                    VStack(alignment: .leading) {
                        Text("Confidence Threshold: \(Int(config.moodConfidenceThreshold * 100))%")
                        Slider(value: $config.moodConfidenceThreshold, in: 0.1 ... 1.0, step: 0.05)
                    }

                    VStack(alignment: .leading) {
                        Text("Update Interval: \(String(format: "%.1f", config.moodUpdateInterval)) seconds")
                        Slider(value: $config.moodUpdateInterval, in: 0.1 ... 5.0, step: 0.1)
                    }

                    Toggle("Use Core ML", isOn: $config.useCoreMLForMoodDetection)

                    Toggle("Enable Mood Smoothing", isOn: $config.enableMoodSmoothing)

                    if config.enableMoodSmoothing {
                        VStack(alignment: .leading) {
                            Text("Smoothing Factor: \(String(format: "%.2f", config.moodSmoothingFactor))")
                            Slider(value: $config.moodSmoothingFactor, in: 0.1 ... 0.9, step: 0.05)
                        }
                    }
                }
            }

            // Device Adaptation
            Section {
                Toggle("Adapt to Device Capabilities", isOn: $config.adaptToDeviceCapabilities)

                if config.adaptToDeviceCapabilities {
                    Toggle("Background Processing", isOn: $config.backgroundProcessingEnabled)
                }
            }

            // Reset Button
            Section {
                Button("Reset to Default Configuration") {
                    config.resetToDefaults()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Audio Processing")
        .onAppear {
            // Setup error notification listener
            setupErrorListener()
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(
                title: Text("Configuration Error"),
                message: Text(errorMessages.joined(separator: "\n")),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func setupErrorListener() {
        config.validationFailed
            .receive(on: RunLoop.main)
            .sink { errors in
                errorMessages = errors
                showingErrorAlert = true
            }
            .store(in: &cancellables)
    }

    private func iconForPreset(_ preset: ConfigurationPreset) -> String {
        switch preset {
        case .performance:
            "gauge.high"
        case .quality:
            "waveform"
        case .battery:
            "battery.100"
        case .realtime:
            "clock"
        case .analysis:
            "chart.bar"
        }
    }

    // Store AnyCancellable objects for Combine subscriptions
    @State private var cancellables = Set<AnyCancellable>()
}

struct AudioProcessingConfigView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AudioProcessingConfigView()
        }
    }
}
