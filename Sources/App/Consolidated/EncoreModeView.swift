//  EncoreModeView.swift
//  Presents a unified surface for AI-assisted playback, podcasts, sensor-driven adaptation,
//  and quick personalization controls (“Encore Mode”). Built with Noir design primitives.
//  Keeps logic minimal; delegates intelligence to AIIntegrationService & SensorFusionService.
import DesignSystem
import SwiftUI

struct EncoreModeView: View {
    @ObservedObject var aiService: AIIntegrationService
    @ObservedObject var sensorService: SensorFusionService

    @State private var personalityInfluence: Double = 0.6
    @State private var showAdvanced = false
    @State private var crossfadeSeconds: Double = 4
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                GlassToolbar("Encore Mode")
                    .padding(.top, 8)

                nowPlayingCard
                mixtapeSuggestionsCard
                podcastSwivelCard
                sensorSnapshotCard
                customizationCard

                Button(role: .cancel) { dismiss() } label: {
                    Text("Done").frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(NoirPalette.background.ignoresSafeArea())
        .onChange(of: sensorService.latest) { _, snap in
            if let snap { aiService.ingest(sensorSnapshot: snap) }
        }
        .onAppear { personalityInfluence = 0.6 }
    }

    private var nowPlayingCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Now Playing")
                        .font(.headline)
                        .foregroundColor(NoirPalette.onGlass)
                    Spacer()
                    Circle().fill(aiService.moodEngine.currentMood.color)
                        .frame(width: 12, height: 12)
                        .accessibilityLabel(Text("Mood \(aiService.moodEngine.currentMood.rawValue)"))
                }
                Text(currentTrackTitle)
                    .foregroundColor(NoirPalette.subduedText)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    moodBadge(aiService.moodEngine.currentMood)
                    moodBadge(aiService.personalityEngine.currentPersonality.moodBias)
                }
            }
        }
    }

    private var mixtapeSuggestionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Personalized Mixtapes")
                        .font(.headline).foregroundColor(NoirPalette.onGlass)
                    Spacer()
                }
                ForEach(recommendationSlots, id: \.self) { slot in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(slot.title)
                                .foregroundColor(NoirPalette.onGlass)
                            Text(slot.subtitle)
                                .font(.caption)
                                .foregroundColor(NoirPalette.subduedText)
                        }
                        Spacer()
                        Button("Play") {
                            aiService.trackInteraction(type: "play_suggested_\(slot.id)")
                        }
                        .buttonStyle(GlassButtonStyle())
                    }
                    .padding(.vertical, 4)
                    Divider().opacity(slot == recommendationSlots.last ? 0 : 0.2)
                }
            }
        }
    }

    private var podcastSwivelCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Podcast Swivel")
                    .font(.headline).foregroundColor(NoirPalette.onGlass)
                Text("Seamlessly crossfade from music into a context-aware podcast segment.")
                    .font(.caption)
                    .foregroundColor(NoirPalette.subduedText)
                HStack {
                    Text("Crossfade: \(Int(crossfadeSeconds))s")
                        .font(.caption)
                        .foregroundColor(NoirPalette.subduedText)
                    Slider(value: $crossfadeSeconds, in: 2 ... 12, step: 1)
                        .tint(aiService.moodEngine.currentMood.color)
                }
                Button("Swivel Now") {
                    aiService.trackInteraction(type: "swivel_podcast_\(Int(crossfadeSeconds))")
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
    }

    private var sensorSnapshotCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Live Sensors")
                    .font(.headline).foregroundColor(NoirPalette.onGlass)
                if let snap = sensorService.latest {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        gridRow(label: "Heart Rate", value: "\(snap.heartRate) bpm")
                        gridRow(label: "Energy", value: percent(snap.energyLevel))
                        gridRow(label: "Stress", value: percent(snap.stressScore))
                        gridRow(label: "Focus", value: percent(snap.focusScore))
                    }
                } else {
                    ProgressView().progressViewStyle(.circular).tint(NoirPalette.accent)
                }
            }
        }
    }

    private var customizationCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Customization")
                        .font(.headline).foregroundColor(NoirPalette.onGlass)
                    Spacer()
                    Button(role: .none) { withAnimation { showAdvanced.toggle() } } label: {
                        Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                            .foregroundColor(NoirPalette.subduedText)
                    }.buttonStyle(.plain)
                }
                Toggle("Adaptive Mood Transitions", isOn: $aiService.moodEngine.adaptToContext)
                    .tint(aiService.moodEngine.currentMood.color)
                if showAdvanced {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Personality Influence")
                            .font(.caption)
                            .foregroundColor(NoirPalette.subduedText)
                        Slider(value: $personalityInfluence, in: 0 ... 1)
                            .tint(NoirPalette.accent)
                        Text(personalityInfluence, format: .percent.precision(.fractionLength(0)))
                            .font(.caption2)
                            .foregroundColor(NoirPalette.subduedText)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var currentTrackTitle: String { "(demo) Track" }
    private struct RecSlot: Hashable { let id: String
        let title: String
        let subtitle: String
    }

    private var recommendationSlots: [RecSlot] {
        [
            RecSlot(id: "energy_boost", title: "Energy Boost Mix", subtitle: "Lift mood • tempo+"),
            RecSlot(id: "focus_flow", title: "Focus Flow", subtitle: "Instrumental • low distraction"),
            RecSlot(id: "evening_unwind", title: "Evening Unwind", subtitle: "Calm acoustic • relax"),
        ]
    }

    private func moodBadge(_ mood: Mood) -> some View {
        Text(mood.rawValue.capitalized)
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(mood.color.opacity(0.18))
            .clipShape(Capsule())
            .foregroundColor(NoirPalette.onGlass)
    }

    private func gridRow(label: String, value: String) -> some View {
        GridRow {
            Text(label).font(.caption).foregroundColor(NoirPalette.subduedText)
            Text(value).font(.caption).foregroundColor(NoirPalette.onGlass)
        }
    }

    private func percent(_ v: Double) -> String { (v as NSNumber).doubleValue
        .formatted(.percent.precision(.fractionLength(0)))
    }
}
