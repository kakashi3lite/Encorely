//
//  NewMixTapeView.swift
//  Mixtapes
//
//  Created by Swanand Tanavade on 03/25/23.
//  Updated by Claude AI on 05/16/25.
//

import CoreData
import SwiftUI
import UniformTypeIdentifiers

struct NewMixTapeView: View {
    // Environment and state
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: MixTape.entity(), sortDescriptors: []) var mixTapes: FetchedResults<MixTape>

    // State variables
    @State var tapeTitle: String = ""
    @State private var showingDocsPicker: Bool = false
    @State private var showingImagePicker: Bool = false
    @State var mixTapePicked: Bool = false
    @State var imagePicked: Bool = false
    @Binding var isPresented: Bool

    // AI service
    var aiService: AIIntegrationService

    // AI-suggested titles
    @State private var suggestedTitles: [String] = []

    // Validate mixtape name
    var inValidName: Bool {
        // mixtape names must be unique to preserve NavigationView functionality
        let bool = mixTapes.contains { $0.title == tapeTitle }
        return bool
    }

    // Helper function to determine background color for title buttons
    private func backgroundColorForTitle(_ title: String) -> Color {
        if tapeTitle == title {
            aiService.personalityEngine.currentPersonality.themeColor
        } else {
            Color.gray.opacity(0.1)
        }
    }

    // MARK: - View Components

    private var mixtapeNameSection: some View {
        Section(header: Text("Mixtape Name")) {
            TextField("Enter Mixtape Name: ", text: $tapeTitle)
        }
        .disabled(mixTapePicked)
    }

    private var suggestedNamesSection: some View {
        Section(header: Text("Suggested Names")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestedTitles, id: \.self) { title in
                        titleButton(for: title)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func titleButton(for title: String) -> some View {
        Button(action: {
            tapeTitle = title
            aiService.trackInteraction(type: "select_suggested_title")
        }) {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(backgroundColorForTitle(title)))
                .foregroundColor(tapeTitle == title ? .white : .primary)
        }
    }

    private var moodTagsSection: some View {
        Section(header: Text("Mood Tags (Optional)")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Mood.allCases, id: \.self) { mood in
                        moodButton(for: mood)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func moodButton(for mood: Mood) -> some View {
        Button(action: {
            aiService.trackInteraction(type: "select_mood_tag_\(mood.rawValue)")
        }) {
            HStack {
                Image(systemName: mood.systemIcon)
                    .foregroundColor(mood.color)

                Text(mood.rawValue)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(mood.color, lineWidth: 1))
        }
    }

    private var addSongsSection: some View {
        Section {
            Button(action: { showingDocsPicker.toggle() }) {
                HStack {
                    Image(systemName: "folder.badge.plus").imageScale(.large)
                    Text("Add Songs")
                }
            }
            .fileImporter(
                isPresented: $showingDocsPicker,
                allowedContentTypes: [UTType.audio],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case let .success(urls):
                    // Handle selected audio files
                    handleSelectedAudioFiles(urls)
                case let .failure(error):
                    print("File import error: \(error)")
                }
            }
        }
        .disabled(tapeTitle.isEmpty || inValidName || mixTapePicked)
    }

    private var addCoverImageSection: some View {
        Section {
            Button(action: { showingImagePicker.toggle() }) {
                HStack {
                    Image(systemName: "photo").imageScale(.large)
                    Text("Add Cover Image")
                }
            }
            .fileImporter(
                isPresented: $showingImagePicker,
                allowedContentTypes: [UTType.image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    if let imageURL = urls.first {
                        handleSelectedImage(imageURL)
                    }
                case let .failure(error):
                    print("Image import error: \(error)")
                }
            }
        }
        .disabled(imagePicked || !mixTapePicked)
    }

    private var finishSection: some View {
        Section {
            Button(action: {
                isPresented.toggle()
                aiService.trackInteraction(type: "create_mixtape")
            }) {
                Text("Add Mixtape")
            }
        }
        .disabled(!mixTapePicked)
    }

    private var cancelButton: some View {
        Button("Cancel") {
            isPresented.toggle()
        }
    }

    var body: some View {
        NavigationView {
            Form {
                mixtapeNameSection
                suggestedNamesSection
                moodTagsSection
                addSongsSection
                addCoverImageSection
                finishSection
            }
            .navigationBarTitle("New Mixtape", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                loadSuggestedTitles()
            }
        }
    }

    // Load AI-suggested mixtape titles
    func loadSuggestedTitles() {
        generateAISuggestions()
    }

    private func generateAISuggestions() {
        var titles: [String] = []

        // Generate basic mood-based suggestions
        let moodBasedTitles = [
            "Chill Vibes", "Energy Boost", "Focus Flow", "Happy Moments",
            "Relaxing Evening", "Workout Mix", "Study Session", "Road Trip",
        ]

        titles.append(contentsOf: moodBasedTitles.shuffled().prefix(4))

        // Ensure we have at least some default suggestions
        if titles.isEmpty {
            titles = [
                "My Mixtape",
                "Favorites Collection",
                "New Mixtape",
                "Playlist 1",
                "Music Collection",
            ]
        }

        // Update the published property on main thread
        DispatchQueue.main.async {
            suggestedTitles = titles

            // Default to first suggestion if title is empty
            if tapeTitle.isEmpty, !titles.isEmpty {
                tapeTitle = titles.first!
            }
        }
    }

    // MARK: - Helper Functions

    private func handleSelectedAudioFiles(_ urls: [URL]) {
        // Process selected audio files and create songs
        for url in urls {
            // Create a new song entity
            let newSong = Song(context: moc)
            newSong.name = url.deletingPathExtension().lastPathComponent
            newSong.urlData = try? Data(contentsOf: url)
            newSong.positionInTape = Int16(mixTapes.first(where: { $0.title == tapeTitle })?.songsArray.count ?? 0)

            // Find or create the mixtape
            if let existingMixTape = mixTapes.first(where: { $0.title == tapeTitle }) {
                newSong.mixTape = existingMixTape
            } else {
                let newMixTape = MixTape(context: moc)
                newMixTape.title = tapeTitle
                newMixTape.createdDate = Date()
                newSong.mixTape = newMixTape
            }
        }

        // Save the context
        do {
            try moc.save()
            mixTapePicked = true
        } catch {
            print("Error saving audio files: \(error)")
        }
    }

    private func handleSelectedImage(_ url: URL) {
        // Handle selected cover image
        if let mixTape = mixTapes.first(where: { $0.title == tapeTitle }) {
            // Convert image URL to Data
            if let imageData = try? Data(contentsOf: url) {
                mixTape.coverImageData = imageData
            }

            do {
                try moc.save()
                imagePicked = true
            } catch {
                print("Error saving cover image: \(error)")
            }
        }
    }
}
