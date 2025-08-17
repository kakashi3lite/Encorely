import SwiftUI

struct AudioSettingsView: View {
    @AppStorage("audioQualityPreference") private var audioQuality = AudioQuality.high
    @AppStorage("enableGaplessPlayback") private var enableGaplessPlayback = true
    @AppStorage("enableNormalization") private var enableNormalization = true
    @AppStorage("normalizationLevel") private var normalizationLevel = 0.0

    enum AudioQuality: String, CaseIterable {
        case low = "Low (96 kbps)"
        case medium = "Medium (192 kbps)"
        case high = "High (320 kbps)"
        case lossless = "Lossless"

        var bitrate: Int {
            switch self {
            case .low: 96
            case .medium: 192
            case .high: 320
            case .lossless: 1411
            }
        }
    }

    var body: some View {
        NavigationContainer {
            Form {
                Section(header: Text("Playback Quality")) {
                    Picker("Audio Quality", selection: $audioQuality) {
                        ForEach(AudioQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue)
                                .tag(quality)
                        }
                    }
                    .pickerStyle(.inline)

                    Text("Higher quality uses more data and storage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Playback Options")) {
                    Toggle("Gapless Playback", isOn: $enableGaplessPlayback)
                        .accessibilityHint("Enable seamless transitions between songs")

                    Toggle("Volume Normalization", isOn: $enableNormalization)
                        .accessibilityHint("Maintain consistent volume across tracks")

                    if enableNormalization {
                        VStack(alignment: .leading) {
                            Text("Normalization Level")
                                .font(.subheadline)

                            Slider(value: $normalizationLevel, in: -12 ... 12, step: 1) {
                                Text("Level")
                            } minimumValueLabel: {
                                Text("-12 dB")
                                    .font(.caption)
                            } maximumValueLabel: {
                                Text("+12 dB")
                                    .font(.caption)
                            }

                            Text("\(Int(normalizationLevel)) dB")
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.top, 4)
                    }
                }

                Section(footer: Text("Changes will apply to new playback sessions")) {
                    // This space intentionally left empty for visual balance
                }
            }
        }
        .navigationTitle("Audio Settings")
        .formStyle(.grouped)
    }
}
