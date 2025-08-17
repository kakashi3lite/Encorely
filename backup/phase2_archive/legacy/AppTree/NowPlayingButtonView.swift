//
//  NowPlayingButtonView.swift
//  Mixtapes
//
//  Created by Swanand Tanavade on 03/25/23.
//  Updated by Claude AI on 05/16/25.
//

import AVKit
import SwiftUI

struct NowPlayingButtonView: View {
    // Core properties
    @Binding var showingNowPlayingSheet: Bool
    let queuePlayer: AVQueuePlayer
    let currentItemObserver: PlayerItemObserver
    @ObservedObject var currentSongName: CurrentSongName
    @ObservedObject var isPlaying: IsPlaying

    // AI service
    var aiService: AIIntegrationService

    // Animation state
    @State private var isAnimating = false
    @State private var showVolumeSlider = false

    var body: some View {
        VStack(spacing: 0) {
            // Main now playing bar
            HStack {
                // Album art / mood indicator
                ZStack {
                    Circle()
                        .fill(aiService.moodEngine.currentMood.color.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: aiService.moodEngine.currentMood.systemIcon)
                        .font(.system(size: 16))
                        .foregroundColor(aiService.moodEngine.currentMood.color)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(
                            isPlaying.value ?
                                Animation.linear(duration: 4).repeatForever(autoreverses: false) :
                                .default,
                            value: isAnimating
                        )
                }
                .onAppear {
                    isAnimating = isPlaying.value
                }
                .onChange(of: isPlaying.value) { newValue in
                    isAnimating = newValue
                }

                // Song info - tappable to expand player
                Button(action: {
                    showingNowPlayingSheet.toggle()
                    aiService.trackInteraction(type: "open_player")
                }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentSongName.wrappedValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Text("Now Playing")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Playback controls
                HStack(spacing: 16) {
                    // Play/Pause
                    Button(action: {
                        if isPlaying.value {
                            queuePlayer.pause()
                            aiService.trackInteraction(type: "pause")
                        } else {
                            queuePlayer.play()
                            aiService.trackInteraction(type: "play")
                        }
                    }) {
                        Image(systemName: isPlaying.value ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                            .foregroundColor(aiService.personalityEngine.currentPersonality.themeColor)
                    }

                    // Skip forward
                    Button(action: {
                        queuePlayer.advanceToNextItem()
                        aiService.trackInteraction(type: "next_track")
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    // Frosted glass effect
                    Color(.systemBackground)
                        .opacity(0.95)

                    // Subtle gradient based on mood
                    LinearGradient(
                        gradient: Gradient(colors: [
                            aiService.moodEngine.currentMood.color.opacity(0.05),
                            aiService.personalityEngine.currentPersonality.themeColor.opacity(0.05),
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                })
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.separator)),
                alignment: .top
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now playing control bar")
        .accessibilityAddTraits(.updatesFrequently)
    }
}
