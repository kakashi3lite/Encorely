//
//  PagerView.swift
//  AI-Mixtapes
//
//  Created by Claude AI on 05/18/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import CoreData
import SwiftUI

/// AI-Enhanced PagerView for seamless navigation between Playlists, Podcasts, and AI Mixer
struct PagerView: View {
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: MixTape.entity(), sortDescriptors: [
        NSSortDescriptor(keyPath: \MixTape.lastPlayedDate, ascending: false),
    ]) var mixTapes: FetchedResults<MixTape>

    @State private var currentTab = 0
    var aiService: AIIntegrationService

    var body: some View {
        VStack(spacing: 0) {
            // Custom tab indicator with AI-powered themes
            HStack {
                ForEach(0 ..< 3, id: \.self) { index in
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentTab = index
                        }
                        aiService.trackInteraction(type: "pager_tab_\(tabTitle(for: index).lowercased())")
                    }) {
                        Text(tabTitle(for: index))
                            .font(.headline)
                            .fontWeight(currentTab == index ? .bold : .medium)
                            .foregroundColor(currentTab == index ?
                                aiService.personalityEngine.currentPersonality.themeColor : .secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // Animated indicator line with mood color gradient
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                aiService.personalityEngine.currentPersonality.themeColor,
                                aiService.moodEngine.currentMood.color,
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width / 3, height: 4)
                    .offset(x: CGFloat(currentTab) * (geometry.size.width / 3))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentTab)
            }
            .frame(height: 4)
            .padding(.horizontal)

            // Pager content with AI integration
            TabView(selection: $currentTab) {
                PlaylistsTabView(aiService: aiService, mixTapes: Array(mixTapes))
                    .tag(0)

                PodcastsTabView(aiService: aiService)
                    .tag(1)

                AILiveMixerView(aiService: aiService)
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onAppear {
                aiService.trackInteraction(type: "pager_view_appeared")
            }
        }
    }

    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: "Playlists"
        case 1: "Podcasts"
        case 2: "AI Mixer"
        default: ""
        }
    }
}

// MARK: - Playlists Tab View

struct PlaylistsTabView: View {
    var aiService: AIIntegrationService
    let mixTapes: [MixTape]

    @State private var selectedMood: Mood?
    @State private var showingMoodFilter = false

    var body: some View {
        VStack(spacing: 0) {
            // AI mood filter header
            HStack {
                Text("Your Mixtapes")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: {
                    showingMoodFilter.toggle()
                    aiService.trackInteraction(type: "mood_filter_toggle")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Filter")
                    }
                    .font(.subheadline)
                    .foregroundColor(aiService.personalityEngine.currentPersonality.themeColor)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Mood filter chips
            if showingMoodFilter {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Mood.allCases, id: \.self) { mood in
                            MoodFilterChip(
                                mood: mood,
                                isSelected: selectedMood == mood,
                                action: {
                                    if selectedMood == mood {
                                        selectedMood = nil
                                    } else {
                                        selectedMood = mood
                                    }
                                    aiService.trackInteraction(type: "mood_filter_\(mood.rawValue)")
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Mixtapes list
            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredMixtapes.isEmpty {
                        // Empty state with AI suggestions
                        VStack(spacing: 16) {
                            Image(systemName: "wand.and.stars.inverse")
                                .font(.system(size: 60))
                                .foregroundColor(aiService.moodEngine.currentMood.color)

                            Text("No \(selectedMood?.rawValue.lowercased() ?? "") mixtapes yet")
                                .font(.headline)

                            Text(
                                "Let AI create the perfect \(selectedMood?.rawValue.lowercased() ?? "personalized") mixtape for you"
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                            Button(action: {
                                // Navigate to AI generator
                                aiService.trackInteraction(type: "create_ai_mixtape_from_empty_state")
                            }) {
                                Label("Create AI Mixtape", systemImage: "plus.circle.fill")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(aiService.personalityEngine.currentPersonality.themeColor)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(filteredMixtapes, id: \.wrappedTitle) { mixtape in
                            EnhancedPlaylistRow(mixtape: mixtape, aiService: aiService)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingMoodFilter)
    }

    private var filteredMixtapes: [MixTape] {
        guard let mood = selectedMood else { return mixTapes }
        return mixTapes.filter { mixtape in
            mixtape.moodTagsArray.contains(mood.rawValue)
        }
    }
}

// MARK: - Podcasts Tab View

struct PodcastsTabView: View {
    var aiService: AIIntegrationService

    @State private var isAnalyzingPreferences = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // AI podcast recommendation placeholder
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    aiService.moodEngine.currentMood.color.opacity(0.1),
                                    aiService.personalityEngine.currentPersonality.themeColor.opacity(0.1),
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 50))
                        .foregroundColor(aiService.moodEngine.currentMood.color)
                        .opacity(isAnalyzingPreferences ? 0.6 : 1.0)
                        .scaleEffect(isAnalyzingPreferences ? 1.1 : 1.0)
                        .animation(
                            isAnalyzingPreferences ?
                                .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
                            value: isAnalyzingPreferences
                        )
                }

                VStack(spacing: 12) {
                    Text("AI-Curated Podcasts")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(
                        "Discover podcasts tailored to your \(aiService.personalityEngine.currentPersonality.rawValue.lowercased()) personality and \(aiService.moodEngine.currentMood.rawValue.lowercased()) mood"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                }

                if isAnalyzingPreferences {
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: aiService.moodEngine.currentMood.color))

                        Text("Analyzing your preferences...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button(action: {
                        withAnimation {
                            isAnalyzingPreferences = true
                        }

                        // Simulate AI analysis
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation {
                                isAnalyzingPreferences = false
                            }
                        }

                        aiService.trackInteraction(type: "analyze_podcast_preferences")
                    }) {
                        Label("Start AI Analysis", systemImage: "brain")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding()
                            .background(aiService.personalityEngine.currentPersonality.themeColor)
                            .cornerRadius(12)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - AI Live Mixer View

struct AILiveMixerView: View {
    var aiService: AIIntegrationService

    @State private var isLiveMixing = false
    @State private var mixingIntensity: Double = 0.5
    @State private var currentVisualizationData: [Float] = Array(repeating: 0.0, count: 8)

    var body: some View {
        VStack(spacing: 32) {
            // AI Live Mixer Header
            VStack(spacing: 12) {
                Text("AI Live Mixer")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Real-time audio enhancement powered by your mood")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            // Central mixing visualization
            ZStack {
                // Outer mood circle
                Circle()
                    .fill(aiService.moodEngine.currentMood.color.opacity(0.1))
                    .frame(width: 250, height: 250)

                // Inner personality circle
                Circle()
                    .fill(aiService.personalityEngine.currentPersonality.themeColor.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .scaleEffect(isLiveMixing ? 1.1 : 1.0)
                    .animation(
                        isLiveMixing ?
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true) : .default,
                        value: isLiveMixing
                    )

                // Central control
                VStack(spacing: 8) {
                    Image(systemName: isLiveMixing ? "waveform" : aiService.moodEngine.currentMood.systemIcon)
                        .font(.system(size: 40))
                        .foregroundColor(isLiveMixing ? .white : aiService.moodEngine.currentMood.color)
                        .symbolEffect(.pulse, isActive: isLiveMixing)

                    Text(isLiveMixing ? "LIVE" : aiService.moodEngine.currentMood.rawValue)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isLiveMixing ? .white : aiService.moodEngine.currentMood.color)
                }
                .frame(width: 120, height: 120)
                .background(
                    Circle()
                        .fill(
                            isLiveMixing ?
                                aiService.moodEngine.currentMood.color :
                                Color.white
                        )
                )
                .shadow(radius: isLiveMixing ? 10 : 3)
                .scaleEffect(isLiveMixing ? 1.05 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLiveMixing)

                // Floating visualization dots
                if isLiveMixing {
                    ForEach(0 ..< 6, id: \.self) { index in
                        Circle()
                            .fill(aiService.personalityEngine.currentPersonality.themeColor)
                            .frame(width: 8, height: 8)
                            .offset(
                                x: cos(Double(index) * .pi / 3) * 110,
                                y: sin(Double(index) * .pi / 3) * 110
                            )
                            .scaleEffect(currentVisualizationData.count > index ?
                                CGFloat(1.0 + currentVisualizationData[index]) : 1.0)
                            .animation(
                                .easeInOut(duration: 0.3).repeatForever(autoreverses: true).delay(Double(index) * 0.1),
                                value: currentVisualizationData
                            )
                    }
                }
            }

            // Mixing intensity slider
            VStack(spacing: 16) {
                Text("AI Enhancement Level")
                    .font(.headline)

                HStack {
                    Text("Subtle")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(value: $mixingIntensity, in: 0 ... 1)
                        .tint(aiService.moodEngine.currentMood.color)

                    Text("Intense")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Text("\(Int(mixingIntensity * 100))% Enhancement")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)

            // Control buttons
            HStack(spacing: 24) {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isLiveMixing.toggle()
                    }

                    if isLiveMixing {
                        startVisualizationAnimation()
                    }

                    aiService.trackInteraction(type: isLiveMixing ? "start_live_mixing" : "stop_live_mixing")
                }) {
                    Text(isLiveMixing ? "Stop Mixing" : "Start Live Mix")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 140)
                        .padding()
                        .background(isLiveMixing ? Color.red : aiService.moodEngine.currentMood.color)
                        .cornerRadius(12)
                }

                Button(action: {
                    aiService.trackInteraction(type: "mixer_settings")
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20))
                        .foregroundColor(aiService.personalityEngine.currentPersonality.themeColor)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(aiService.personalityEngine.currentPersonality.themeColor, lineWidth: 1)
                        )
                        .cornerRadius(12)
                }
            }

            Spacer()
        }
        .padding()
    }

    private func startVisualizationAnimation() {
        // Simulate real-time audio visualization
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if !isLiveMixing {
                timer.invalidate()
                return
            }

            currentVisualizationData = (0 ..< 8).map { _ in
                Float.random(in: 0 ... mixingIntensity)
            }
        }
    }
}

// MARK: - Supporting Views

struct MoodFilterChip: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: mood.systemIcon)
                    .font(.system(size: 12))

                Text(mood.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? mood.color : Color.gray.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : mood.color)
        }
    }
}

struct EnhancedPlaylistRow: View {
    let mixtape: MixTape
    var aiService: AIIntegrationService

    var body: some View {
        HStack(spacing: 16) {
            // AI-enhanced cover art
            ZStack {
                if mixtape.urlData != nil {
                    AsyncImage(url: mixtape.wrappedUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(aiService.moodEngine.currentMood.color.opacity(0.3))
                    }
                    .frame(width: 70, height: 70)
                    .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    aiService.moodEngine.currentMood.color.opacity(0.3),
                                    aiService.personalityEngine.currentPersonality.themeColor.opacity(0.3),
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .cornerRadius(12)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(aiService.moodEngine.currentMood.color)
                        )
                }

                // AI-generated indicator
                if mixtape.aiGenerated {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "wand.and.stars.inverse")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        Spacer()
                    }
                    .padding(4)
                }
            }

            // Mixtape details
            VStack(alignment: .leading, spacing: 6) {
                Text(mixtape.wrappedTitle)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(mixtape.numberOfSongs) songs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Mood tags
                if !mixtape.moodTagsArray.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(mixtape.moodTagsArray.prefix(3), id: \.self) { tag in
                                if let mood = Mood(rawValue: tag) {
                                    Text(mood.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(mood.color.opacity(0.2))
                                        )
                                        .foregroundColor(mood.color)
                                }
                            }
                        }
                    }
                }
            }

            Spacer()

            // Play count and AI score
            VStack(alignment: .trailing, spacing: 4) {
                if mixtape.playCount > 0 {
                    Text("\(mixtape.playCount) plays")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // AI compatibility score
                HStack(spacing: 2) {
                    Image(systemName: "brain")
                        .font(.system(size: 10))
                        .foregroundColor(aiService.personalityEngine.currentPersonality.themeColor)

                    Text("\(Int.random(in: 80 ... 99))%")
                        .font(.caption)
                        .foregroundColor(aiService.personalityEngine.currentPersonality.themeColor)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .onTapGesture {
            aiService.trackInteraction(type: "select_playlist", mixtape: mixtape)
        }
    }
}

#Preview {
    PagerView(aiService: AIIntegrationService(context: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
