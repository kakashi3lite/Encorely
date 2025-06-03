//
//  ContentView.swift
//  Mixtapes
//
//  Created by Swanand Tanavade on 03/25/23.
//  Updated by Claude AI on 05/16/25.
//

import SwiftUI
import CoreData
import AVKit
import AIMixtapes // Contains SharedTypes

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var audioProcessor: AudioProcessor
    @Environment(\.managedObjectContext) var moc
    
    @FetchRequest(
        entity: MixTape.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \MixTape.lastPlayedDate, ascending: false)
        ]
    ) var mixTapes: FetchedResults<MixTape>
    
    // UI State
    @State private var showingNewMixTape = false
    @State private var showingSettings = false
    @State private var selectedMood: Mood = .neutral
    
    var body: some View {
        NavigationView {
            List {
                // Current Mixtape
                if let currentMixTape = appState.currentMixTape {
                    NowPlayingView(mixTape: currentMixTape)
                        .listRowInsets(EdgeInsets())
                }
                
                // Mixtape List
                ForEach(mixTapes) { mixTape in
                    MixTapeRowView(mixTape: mixTape)
                        .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("AI Mixtapes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingNewMixTape = true }) {
                        Label("New Mixtape", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigation) {
                    Button(action: { showingSettings = true }) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingNewMixTape) {
                NewMixTapeView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
        .overlay(
            ProcessingOverlay()
                .opacity(appState.isProcessing ? 1 : 0)
        )
        .alert("Error", isPresented: .constant(appState.errorMessage != nil)) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}

// MARK: - Supporting Views
private struct ProcessingOverlay: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Processing...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .ignoresSafeArea()
    }
}

private struct MixTapeRowView: View {
    let mixTape: MixTape
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: { playMixTape(mixTape) }) {
            HStack {
                // Mood Icon
                Image(systemName: mixTape.mood.iconName)
                    .foregroundColor(mixTape.mood.color)
                    .font(.title2)
                    .frame(width: 40)
                
                VStack(alignment: .leading) {
                    Text(mixTape.name)
                        .font(.headline)
                    Text("\(mixTape.songs.count) songs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if appState.currentMixTape?.id == mixTape.id {
                    Image(systemName: "music.note")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
        }
    }
    
    private func playMixTape(_ mixTape: MixTape) {
        appState.currentMixTape = mixTape
        // Additional playback logic here
    }
}
