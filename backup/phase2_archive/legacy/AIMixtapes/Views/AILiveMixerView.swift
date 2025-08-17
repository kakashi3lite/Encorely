import AVKit
import SwiftUI

struct AILiveMixerView: View {
    var aiService: AIIntegrationService

    @State private var tracks: [MixerTrack] = []
    @State private var isRecording = false
    @State private var mixProgress: Double = 0
    @State private var selectedEffect: AudioEffect = .none
    @State private var selectedTransition: TransitionType = .crossfade
    @State private var bpm: Double = 120
    @State private var volume: Double = 0.8
    @State private var showingLoadDialog = false
    @State private var showingEffectsSheet = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Mixer header
                HStack {
                    VStack(alignment: .leading) {
                        Text("AI Live Mixer")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Mix with real-time AI assistance")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        withAnimation {
                            isRecording.toggle()
                        }
                        hapticFeedback(style: .medium)
                        aiService.trackInteraction(type: "mixer_recording_\(isRecording ? "started" : "stopped")")
                    }) {
                        Circle()
                            .fill(isRecording ? Color.red : aiService.moodEngine.currentMood.color)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: isRecording ? "stop.fill" : "record.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white))
                    }
                }
                .padding(.horizontal)

                // Track lanes
                VStack(spacing: 16) {
                    ForEach(tracks) { track in
                        TrackLaneView(
                            track: track,
                            mood: aiService.moodEngine.currentMood,
                            onVolumeChange: { adjustVolume(for: track, to: $0) }
                        )
                    }

                    // Add track button
                    Button(action: { showingLoadDialog = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Track")
                        }
                        .font(.headline)
                        .foregroundColor(aiService.moodEngine.currentMood.color)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(aiService.moodEngine.currentMood.color, lineWidth: 2))
                    }
                }
                .padding(.horizontal)

                // Controls section
                VStack(spacing: 20) {
                    // BPM control
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("BPM")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(bpm))")
                                .font(.headline)
                                .foregroundColor(aiService.moodEngine.currentMood.color)
                        }

                        Slider(value: $bpm, in: 60 ... 200) { editing in
                            if !editing {
                                aiService.trackInteraction(type: "mixer_bpm_changed", metadata: ["value": bpm])
                            }
                        }
                        .tint(aiService.moodEngine.currentMood.color)
                    }

                    // Effects and transitions
                    HStack {
                        // Effects
                        Menu {
                            ForEach(AudioEffect.allCases, id: \.self) { effect in
                                Button {
                                    selectedEffect = effect
                                    aiService.trackInteraction(
                                        type: "mixer_effect_selected",
                                        metadata: ["effect": effect.rawValue]
                                    )
                                } label: {
                                    Label(effect.name, systemImage: effect.icon)
                                }
                            }
                        } label: {
                            Label("Effects: \(selectedEffect.name)", systemImage: selectedEffect.icon)
                                .font(.headline)
                        }

                        Spacer()

                        // Transitions
                        Menu {
                            ForEach(TransitionType.allCases, id: \.self) { transition in
                                Button {
                                    selectedTransition = transition
                                    aiService.trackInteraction(
                                        type: "mixer_transition_selected",
                                        metadata: ["transition": transition.rawValue]
                                    )
                                } label: {
                                    Label(transition.name, systemImage: transition.icon)
                                }
                            }
                        } label: {
                            Label("Transition: \(selectedTransition.name)", systemImage: selectedTransition.icon)
                                .font(.headline)
                        }
                    }

                    // Master volume
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Master Volume")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(volume * 100))%")
                                .font(.headline)
                                .foregroundColor(aiService.moodEngine.currentMood.color)
                        }

                        Slider(value: $volume) { editing in
                            if !editing {
                                aiService.trackInteraction(type: "mixer_volume_changed", metadata: ["value": volume])
                            }
                        }
                        .tint(aiService.moodEngine.currentMood.color)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6)))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingLoadDialog) {
            NavigationView {
                TrackPickerView(aiService: aiService) { track in
                    addTrack(track)
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    private func addTrack(_ track: MixerTrack) {
        withAnimation {
            tracks.append(track)
        }
        aiService.trackInteraction(type: "mixer_track_added", metadata: ["id": track.id])
    }

    private func adjustVolume(for track: MixerTrack, to value: Double) {
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            tracks[index].volume = value
            aiService.trackInteraction(type: "mixer_track_volume_changed", metadata: [
                "id": track.id,
                "value": value,
            ])
        }
    }
}

// MARK: - Supporting Types

struct MixerTrack: Identifiable {
    let id: String
    let name: String
    var volume: Double
    var isMuted: Bool
    var effects: [AudioEffect]
}

enum AudioEffect: String, CaseIterable {
    case none
    case reverb
    case delay
    case filter
    case distortion

    var name: String {
        switch self {
        case .none: "None"
        case .reverb: "Reverb"
        case .delay: "Delay"
        case .filter: "Filter"
        case .distortion: "Distortion"
        }
    }

    var icon: String {
        switch self {
        case .none: "waveform"
        case .reverb: "waveform.path.ecg"
        case .delay: "waveform.path"
        case .filter: "waveform.badge.plus"
        case .distortion: "waveform.path.ecg.rectangle"
        }
    }
}

enum TransitionType: String, CaseIterable {
    case crossfade
    case cut
    case fade
    case beatSync

    var name: String {
        switch self {
        case .crossfade: "Crossfade"
        case .cut: "Cut"
        case .fade: "Fade"
        case .beatSync: "Beat Sync"
        }
    }

    var icon: String {
        switch self {
        case .crossfade: "arrow.left.and.right"
        case .cut: "scissors"
        case .fade: "waveform.path.ecg"
        case .beatSync: "metronome"
        }
    }
}

// MARK: - Supporting Views

struct TrackLaneView: View {
    let track: MixerTrack
    let mood: Mood
    let onVolumeChange: (Double) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            // Track header
            HStack {
                Image(systemName: "waveform")
                    .font(.headline)
                    .foregroundColor(mood.color)

                Text(track.name)
                    .font(.headline)

                Spacer()

                Text("\(Int(track.volume * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }

            // Expanded controls
            if isExpanded {
                Slider(value: Binding(
                    get: { track.volume },
                    set: { onVolumeChange($0) }
                ))
                .tint(mood.color)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, y: 2))
    }
}

struct TrackPickerView: View {
    var aiService: AIIntegrationService
    var onTrackSelected: (MixerTrack) -> Void
    @Environment(\.presentationMode) var presentationMode

    let sampleTracks = [
        "Drums",
        "Bass",
        "Lead Synth",
        "Pads",
        "Vocals",
        "Guitar",
        "Piano",
    ]

    var body: some View {
        List(sampleTracks, id: \.self) { trackName in
            Button(action: {
                let track = MixerTrack(
                    id: UUID().uuidString,
                    name: trackName,
                    volume: 0.8,
                    isMuted: false,
                    effects: []
                )
                onTrackSelected(track)
                presentationMode.wrappedValue.dismiss()
            }) {
                Label(trackName, systemImage: "waveform")
            }
        }
        .navigationTitle("Add Track")
        .navigationBarItems(trailing: Button("Cancel") {
            presentationMode.wrappedValue.dismiss()
        })
    }
}

func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}
