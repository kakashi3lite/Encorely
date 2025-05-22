//
//  NewMixTapeView.swift
//  Mixtapes
//
//  Created by Swanand Tanavade on 03/25/23.
//  Updated by Claude AI on 05/16/25.
//

import SwiftUI
import CoreData

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
        let bool = mixTapes.contains{ $0.title == tapeTitle }
        return bool
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Mixtape Name")) {
                    TextField("Enter Mixtape Name: ", text: $tapeTitle)
                }
                .disabled(mixTapePicked)
                
                // AI suggested names
                Section(header: Text("Suggested Names")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(suggestedTitles, id: \.self) { title in
                                Button(action: {
                                    self.tapeTitle = title
                                    aiService.trackInteraction(type: "select_suggested_title")
                                }) {
                                    Text(title)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(self.tapeTitle == title ? 
                                                     aiService.personalityEngine.currentPersonality.themeColor : Color.gray.opacity(0.1))
                                        )
                                        .foregroundColor(self.tapeTitle == title ? .white : .primary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Mood tags selection
                Section(header: Text("Mood Tags (Optional)")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Mood.allCases, id: \.self) { mood in
                                Button(action: {
                                    // In a real app, we would store selected moods for the new mixtape
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
                                            .stroke(mood.color, lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Add songs section
                Section {
                    Button(action: { self.showingDocsPicker.toggle() }) {
                         HStack {
                             Image(systemName: "folder.badge.plus").imageScale(.large)
                             Text("Add Songs")
                         }
                     }
                     .sheet(isPresented: self.$showingDocsPicker) {
                      MixTapePicker(nameofTape: self.tapeTitle, mixTapePicked: self.$mixTapePicked, moc: self.moc)
                     }
                }
                .disabled(tapeTitle.isEmpty || inValidName || mixTapePicked)
                
                // Add cover image section
                Section {
                    Button(action: { self.showingImagePicker.toggle() }) {
                        HStack {
                            Image(systemName: "photo").imageScale(.large)
                            Text("Add Cover Image")
                        }
                     }
                     .sheet(isPresented: self.$showingImagePicker) {
                        ImagePickerView(mixTapes: self.mixTapes, moc: self.moc, imagePicked: self.$imagePicked)
                     }
                }
                .disabled(imagePicked || !mixTapePicked)
                
                // Finish section
                Section {
                    Button(action: { 
                        self.isPresented.toggle()
                        aiService.trackInteraction(type: "create_mixtape")
                    }) {
                        Text("Add Mixtape")
                    }
                }
                .disabled(!mixTapePicked)
            }
            .navigationBarTitle("New Mixtape", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                self.isPresented.toggle()
            })
            .onAppear {
                loadSuggestedTitles()
                aiService.trackInteraction(type: "open_create_mixtape")
            }
        }
    }
    
    // Load AI-suggested mixtape titles
    func loadSuggestedTitles() {
        var titles: [String] = []
        
        // Get mood-based suggestions
        if let moodEngine = aiService.moodEngine {
            for action in moodEngine.getMoodBasedActions() {
                if action.action.contains("create_mixtape_") {
                    let title = action.title
                    if !titles.contains(title) {
                        titles.append(title)
                    }
                }
            }
        }
        
        // Get personality-based suggestions
        if let recommendationEngine = aiService.recommendationEngine {
            let personalitySuggestions = recommendationEngine.getSuggestedMixtapeTitles()
            for title in personalitySuggestions {
                if !titles.contains(title) {
                    titles.append(title)
                }
            }
        }
        
        // Ensure we have at least some default suggestions
        if titles.isEmpty {
            titles = [
                "My Mixtape",
                "Favorites Collection",
                "New Mixtape",
                "Playlist 1",
                "Music Collection"
            ]
        }
        
        // Set the suggestions
        suggestedTitles = titles
        
        // Default to first suggestion if title is empty
        if tapeTitle.isEmpty && !titles.isEmpty {
            tapeTitle = titles.first!
        }
    }
}
