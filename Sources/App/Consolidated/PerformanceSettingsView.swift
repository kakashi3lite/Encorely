import SwiftUI

#if os(macOS)
struct PerformanceSettingsView: View {
    @AppStorage("enableBackgroundProcessing") private var enableBackgroundProcessing = true
    @AppStorage("audioProcessingQuality") private var audioProcessingQuality = "high"
    @AppStorage("maxMemoryUsage") private var maxMemoryUsage = 512.0 // MB
    @AppStorage("maxDiskCache") private var maxDiskCache = 1024.0 // MB
    @AppStorage("enableAutomaticOptimization") private var enableAutomaticOptimization = true
    
    private let audioQualities = ["low", "medium", "high"]
    
    var body: some View {
        Form {
            Section(header: Text("Processing")) {
                Toggle("Enable Background Processing", isOn: $enableBackgroundProcessing)
                    .help("Allow audio analysis and recommendations in the background")
                
                Picker("Audio Processing Quality", selection: $audioProcessingQuality) {
                    ForEach(audioQualities, id: \.self) { quality in
                        Text(quality.capitalized)
                    }
                }
                .help("Higher quality requires more CPU power")
            }
            
            Section(header: Text("Resource Limits")) {
                VStack(alignment: .leading) {
                    Text("Maximum Memory Usage: \(Int(maxMemoryUsage)) MB")
                    Slider(value: $maxMemoryUsage, in: 256...2048, step: 128)
                }
                .help("Adjust the maximum amount of memory the app can use")
                
                VStack(alignment: .leading) {
                    Text("Maximum Disk Cache: \(Int(maxDiskCache)) MB")
                    Slider(value: $maxDiskCache, in: 512...4096, step: 256)
                }
                .help("Adjust the maximum disk space used for caching")
            }
            
            Section(header: Text("Optimization")) {
                Toggle("Enable Automatic Optimization", isOn: $enableAutomaticOptimization)
                    .help("Automatically adjust settings based on system load")
                
                Button("Clear All Caches") {
                    clearAllCaches()
                }
                .help("Remove all cached data to free up space")
            }
            
            Section(header: Text("Advanced Configuration")) {
                NavigationLink(destination: AudioProcessingConfigView()) {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.blue)
                        Text("Audio Processing Configuration")
                    }
                }
                .help("Configure detailed audio processing parameters")
            }
        }
        .padding()
        .frame(width: 400)
        .onChange(of: audioProcessingQuality) { newValue in
            updateAudioProcessingQuality(newValue)
        }
        .onChange(of: maxMemoryUsage) { newValue in
            updateMemoryLimit(newValue)
        }
        .onChange(of: maxDiskCache) { newValue in
            updateDiskCacheLimit(newValue)
        }
    }
    
    private func clearAllCaches() {
        Task {
            await PlayerManager.shared.cleanupResources()
            // Clear other caches as needed
        }
    }
    
    private func updateAudioProcessingQuality(_ quality: String) {
        PlayerManager.shared.audioProcessor?.setQuality(AudioProcessingQuality(rawValue: quality) ?? .high)
    }
    
    private func updateMemoryLimit(_ limit: Double) {
        // Update memory limits in relevant components
        Task {
            await PlayerManager.shared.setMemoryLimit(megabytes: Int(limit))
        }
    }
    
    private func updateDiskCacheLimit(_ limit: Double) {
        // Update disk cache limits in relevant components
        Task {
            await PlayerManager.shared.setDiskCacheLimit(megabytes: Int(limit))
        }
    }
}

// MARK: - Preview
struct PerformanceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceSettingsView()
    }
}
#endif
