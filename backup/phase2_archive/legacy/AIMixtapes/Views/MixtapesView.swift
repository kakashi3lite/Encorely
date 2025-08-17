//
//  MixtapesView.swift
//  AI Mixtapes
//
//  Created by AI Assistant on 2024
//  Copyright © 2024 AI Mixtapes. All rights reserved.
//

import SwiftUI
import MusicKit

struct MixtapesView: View {
    // MARK: - Environment Objects
    @EnvironmentObject private var mixtapeStore: MixtapeStore
    @EnvironmentObject private var appState: AppState
    
    // MARK: - State
    @State private var searchText = ""
    @State private var selectedMood: Mood? = nil
    @State private var sortOption: SortOption = .dateCreated
    @State private var showingSortOptions = false
    @State private var showingDeleteAlert = false
    @State private var mixtapeToDelete: Mixtape?
    @State private var showingGenerateView = false
    
    // MARK: - Computed Properties
    private var filteredMixtapes: [Mixtape] {
        var mixtapes = mixtapeStore.mixtapes
        
        // Filter by search text
        if !searchText.isEmpty {
            mixtapes = mixtapes.filter { mixtape in
                mixtape.name.localizedCaseInsensitiveContains(searchText) ||
                mixtape.songs.contains { song in
                    song.title.localizedCaseInsensitiveContains(searchText) ||
                    song.artist.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        
        // Filter by mood
        if let selectedMood = selectedMood {
            mixtapes = mixtapes.filter { $0.mood == selectedMood }
        }
        
        // Sort
        switch sortOption {
        case .dateCreated:
            return mixtapes.sorted { $0.createdAt > $1.createdAt }
        case .name:
            return mixtapes.sorted { $0.name < $1.name }
        case .duration:
            return mixtapes.sorted { $0.totalDuration > $1.totalDuration }
        case .songCount:
            return mixtapes.sorted { $0.songCount > $1.songCount }
        }
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if mixtapeStore.mixtapes.isEmpty {
                    emptyStateView
                } else {
                    mixtapeListView
                }
            }
            .navigationTitle("My Mixtapes")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search mixtapes...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        sortMenu
                        Divider()
                        moodFilterMenu
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Generate") {
                        showingGenerateView = true
                    }
                }
            }
            .refreshable {
                await mixtapeStore.loadMixtapes()
            }
        }
        .sheet(isPresented: $showingGenerateView) {
            GenerateMixtapeView()
        }
        .alert("Delete Mixtape", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let mixtape = mixtapeToDelete {
                    mixtapeStore.deleteMixtape(mixtape)
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(mixtapeToDelete?.name ?? "")\"? This action cannot be undone.")
        }
    }
    
    // MARK: - View Components
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text("No Mixtapes Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Create your first AI-generated mixtape based on your mood and preferences.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            Button("Generate Your First Mixtape") {
                showingGenerateView = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mixtapeListView: some View {
        List {
            if !filteredMixtapes.isEmpty {
                ForEach(filteredMixtapes) { mixtape in
                    MixtapeListRow(mixtape: mixtape) {
                        mixtapeStore.setCurrentMixtape(mixtape)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) {
                            mixtapeToDelete = mixtape
                            showingDeleteAlert = true
                        }
                        
                        Button("Share") {
                            shareMixtape(mixtape)
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button("Play") {
                            mixtapeStore.setCurrentMixtape(mixtape)
                        }
                        
                        Button("Share") {
                            shareMixtape(mixtape)
                        }
                        
                        Divider()
                        
                        Button("Delete", role: .destructive) {
                            mixtapeToDelete = mixtape
                            showingDeleteAlert = true
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    Text("No mixtapes found")
                        .font(.headline)
                    
                    Text("Try adjusting your search or filters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
    
    private var sortMenu: some View {
        Group {
            Button {
                sortOption = .dateCreated
            } label: {
                Label("Date Created", systemImage: sortOption == .dateCreated ? "checkmark" : "")
            }
            
            Button {
                sortOption = .name
            } label: {
                Label("Name", systemImage: sortOption == .name ? "checkmark" : "")
            }
            
            Button {
                sortOption = .duration
            } label: {
                Label("Duration", systemImage: sortOption == .duration ? "checkmark" : "")
            }
            
            Button {
                sortOption = .songCount
            } label: {
                Label("Song Count", systemImage: sortOption == .songCount ? "checkmark" : "")
            }
        }
    }
    
    private var moodFilterMenu: some View {
        Group {
            Button {
                selectedMood = nil
            } label: {
                Label("All Moods", systemImage: selectedMood == nil ? "checkmark" : "")
            }
            
            ForEach(Mood.allCases, id: \.self) { mood in
                Button {
                    selectedMood = mood
                } label: {
                    Label("\(mood.emoji) \(mood.displayName)", systemImage: selectedMood == mood ? "checkmark" : "")
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func shareMixtape(_ mixtape: Mixtape) {
        // Implement sharing functionality
        let shareText = "Check out my AI-generated mixtape: \(mixtape.name)"
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Supporting Types

enum SortOption: String, CaseIterable {
    case dateCreated = "Date Created"
    case name = "Name"
    case duration = "Duration"
    case songCount = "Song Count"
}

// MARK: - Supporting Views

struct MixtapeListRow: View {
    let mixtape: Mixtape
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Mixtape artwork
                RoundedRectangle(cornerRadius: 12)
                    .fill(mixtape.mood.color.gradient)
                    .frame(width: 60, height: 60)
                    .overlay {
                        VStack(spacing: 2) {
                            Text(mixtape.mood.emoji)
                                .font(.title3)
                            Text("\(mixtape.songCount)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                
                // Mixtape info
                VStack(alignment: .leading, spacing: 4) {
                    Text(mixtape.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text("\(mixtape.songCount) songs • \(mixtape.formattedDuration)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(mixtape.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Play indicator
                if mixtape.id == mixtapeStore.currentMixtape?.id {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.accentColor)
                        .font(.caption)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        MixtapesView()
    }
    .environmentObject(MixtapeStore.preview)
    .environmentObject(AppState())
}

#Preview("Empty State") {
    NavigationView {
        MixtapesView()
    }
    .environmentObject(MixtapeStore())
    .environmentObject(AppState())
}