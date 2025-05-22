//
//  NowPlayingButtonView.swift
//  Mixtapes
//
//  Created by Swanand Tanavade on 03/25/23.
//  Updated by Claude AI on 05/16/25.
//

import SwiftUI
import AVKit

struct NowPlayingButtonView: View {
    // Core properties
    @Binding var showingNowPlayingSheet: Bool
    let queuePlayer: AVQueuePlayer
    let currentItemObserver: PlayerItemObserver
    @ObservedObject var currentSongName: CurrentSongName
    @ObservedObject var isPlaying: IsPlaying
    
    // AI service
    var aiService: AIIntegrationService
    
    var body: some View {
        moodAwareBody
    }
    
    // Mood-aware body
    var moodAwareBody: some View {
        HStack {
            Button(action: {
                self.showingNowPlayingSheet.toggle()
                aiService.trackInteraction(type: "open_player")
            }) {
                HStack() {
                    Button(action: {
                        if self.isPlaying.value {
                            self.queuePlayer.pause()
                            aiService.trackInteraction(type: "pause")
                        } else {
                            self.queuePlayer.play()
                            aiService.trackInteraction(type: "play")
                        }
                    }) {
                        Image(systemName: self.isPlaying.value ? "pause.fill" : "play.fill").imageScale(.large)
                    }
                    
                    Spacer()
                    
                    // Add mood indicator
                    HStack {
                        Text(self.currentSongName.name)
                            .onReceive(currentItemObserver.$currentItem) { item in
                                self.currentSongName.name = getItemName(playerItem: item)
                        }
                        
                        if self.currentSongName.name != "Not Playing" {
                            Circle()
                                .fill(aiService.moodEngine.currentMood.color)
                                .frame(width: 12, height: 12)
                        }
                    }
               }
               .padding()
               .background(
                   LinearGradient(
                       gradient: Gradient(
                           colors: [
                               aiService.personalityEngine.currentPersonality.themeColor.opacity(0.8),
                               aiService.moodEngine.currentMood.color.opacity(0.6)
                           ]
                       ),
                       startPoint: .leading,
                       endPoint: .trailing
                   )
               )
               .foregroundColor(Color.white)
               .cornerRadius(12)
           }
        }
    }
}
