//
//  AIGeneratedMixtapeView.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import SwiftUI
import CoreData
import Combine

struct AIGeneratedMixtapeView: View {
    // MARK: - Properties
    
    @Environment(\.managedObjectContext) var moc
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var moodEngine: MoodEngine
    @ObservedObject var personalityEngine: PersonalityEngine
    @StateObject private var viewModel: AIGeneratedMixtapeViewModel
    
    @State private var showingMoodPicker = false
    @State private var showingPersonalityView = false
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var mixtapeName = ""
    @State private var showingGenreSelector = false
    @State private var selectedGenres: Set<String> = []
    @State private var showingAdvancedOptions = false
    @State private var showingNameSuggestions = false
    @State private var generationPhase = 0.0
    
    private let haptics = UINotificationFeedbackGenerator()
    private let phases = ["Analyzing mood patterns", "Selecting tracks", "Crafting transitions", "Finalizing mixtape"]
    
    // MARK: - Initialization
    
    init(moodEngine: MoodEngine, personalityEngine: PersonalityEngine) {
        self.moodEngine = moodEngine
        self.personalityEngine = personalityEngine
        _viewModel = StateObject(wrappedValue: AIGeneratedMixtapeViewModel(
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header cards
                    headerSection
                    
                    // Name and configuration
                    configurationSection
                    
                    // Generation controls
                    if !isGenerating && viewModel.currentMixtape == nil {
                        generateSection
                    }
                    
                    // Progress or preview
                    if isGenerating {
                        generationProgressSection
                    } else if let mixtape = viewModel.currentMixtape {
                        mixtapePreviewSection(mixtape: mixtape)
                    }
                    
                    // Recent mixtapes
                    if !viewModel.recentMixtapes.isEmpty && !isGenerating {
                        recentMixtapesSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Create AI Mixtape")
            .background(Color(.systemGroupedBackground))
            .animation(.easeInOut, value: isGenerating)
            .animation(.easeInOut, value: viewModel.currentMixtape != nil)
            .sheet(isPresented: $showingMoodPicker) {
                MoodView(moodEngine: moodEngine)
            }
            .sheet(isPresented: $showingPersonalityView) {
                PersonalityView(personalityEngine: personalityEngine)
            }
            .sheet(isPresented: $showingGenreSelector) {
                GenreSelectorView(selectedGenres: $selectedGenres)
            }
            .sheet(isPresented: $showingNameSuggestions) {
                NameSuggestionsView(
                    mixtapeName: $mixtapeName,
                    mood: moodEngine.currentMood,
                    personality: personalityEngine.currentPersonality
                )
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Mood card with 3D effect
            Button(action: { showingMoodPicker = true }) {
                MoodCard(
                    mood: moodEngine.currentMood,
                    isSelected: true
                )
                .rotation3DEffect(
                    .degrees(5),
                    axis: (x: 0.5, y: 1.0, z: 0.0)
                )
            }
            .buttonStyle(SpringButtonStyle())
            
            // Personality card with 3D effect
            Button(action: { showingPersonalityView = true }) {
                PersonalityCard(
                    personality: personalityEngine.currentPersonality,
                    isSelected: true
                )
                .rotation3DEffect(
                    .degrees(-5),
                    axis: (x: -0.5, y: 1.0, z: 0.0)
                )
            }
            .buttonStyle(SpringButtonStyle())
        }
        .padding(.horizontal)
    }
    
    private var configurationSection: some View {
        VStack(spacing: 20) {
            // Mixtape name with suggestions
            HStack {
                TextField("Mixtape Name", text: $mixtapeName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: { showingNameSuggestions = true }) {
                    Image(systemName: "wand.stars")
                        .foregroundColor(moodEngine.currentMood.color)
                }
            }
            .padding(.horizontal)
            
            // Controls grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Song count
                ControlCard(
                    title: "Songs",
                    value: "\(viewModel.songCount)",
                    icon: "music.note.list",
                    color: moodEngine.currentMood.color
                ) {
                    Stepper("", value: $viewModel.songCount, in: 5...20)
                }
                
                // Duration
                ControlCard(
                    title: "Duration",
                    value: "\(viewModel.duration) min",
                    icon: "clock",
                    color: personalityEngine.currentPersonality.themeColor
                ) {
                    Picker("", selection: $viewModel.duration) {
                        Text("30 min").tag(30)
                        Text("45 min").tag(45)
                        Text("60 min").tag(60)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Genres
                ControlCard(
                    title: "Genres",
                    value: "\(selectedGenres.count) selected",
                    icon: "music.note",
                    color: .blue
                ) {
                    Button(action: { showingGenreSelector = true }) {
                        Text("Select")
                            .foregroundColor(.blue)
                    }
                }
                
                // Advanced
                ControlCard(
                    title: "Options",
                    value: showingAdvancedOptions ? "Show" : "Hide",
                    icon: "slider.horizontal.3",
                    color: .purple
                ) {
                    Toggle("", isOn: $showingAdvancedOptions)
                }
            }
            .padding(.horizontal)
            
            if showingAdvancedOptions {
                advancedOptionsSection
            }
        }
    }
    
    private var generateSection: some View {
        VStack {
            Button(action: generateMixtape) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Generate AI Mixtape")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(mixtapeName.isEmpty ? Color.gray : moodEngine.currentMood.color)
                )
                .foregroundColor(.white)
            }
            .disabled(mixtapeName.isEmpty)
            .padding(.horizontal)
            
            if !viewModel.recentMixtapes.isEmpty {
                Text("or choose from your recent creations below")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var generationProgressSection: some View {
        VStack(spacing: 16) {
            // Visual progress
            ZStack {
                Circle()
                    .stroke(lineWidth: 8)
                    .opacity(0.3)
                    .foregroundColor(Color.secondary)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(self.viewModel.generationProgress, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .foregroundColor(Color.accentColor)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear(duration: 0.25), value: viewModel.generationProgress)
                
                VStack {
                    Text("\(Int(viewModel.generationProgress * 100))%")
                        .font(.title)
                        .bold()
                    Text(viewModel.currentGenerationStep ?? "Processing...")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 150, height: 150)
            
            // Current phase indicator
            VStack(spacing: 8) {
                ForEach(viewModel.generationSteps.indices, id: \.self) { index in
                    HStack {
                        Circle()
                            .fill(index <= Int(viewModel.generationProgress * Float(viewModel.generationSteps.count)) ? Color.accentColor : Color.secondary)
                            .frame(width: 8, height: 8)
                        
                        Text(viewModel.generationSteps[index])
                            .font(.subheadline)
                            .foregroundColor(index <= Int(viewModel.generationProgress * Float(viewModel.generationSteps.count)) ? .primary : .secondary)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            
            // Error display
            if viewModel.showingError {
                VStack {
                    Text("Error")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(viewModel.errorMessage ?? "An unknown error occurred")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        retryGeneration()
                    }
                    .padding(.top)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
        }
        .padding()
    }
    
    private var advancedOptionsSection: some View {
        VStack(spacing: 16) {
            // Explicit content toggle
            Toggle("Include explicit content", isOn: $viewModel.includeExplicitContent)
                .toggleStyle(SwitchToggleStyle(tint: moodEngine.currentMood.color))
                .padding(.horizontal)
            
            // Custom mood tag
            HStack {
                Text("Custom Mood Tag")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                TextField("e.g., Chill, Party", text: $viewModel.customMoodTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 150)
            }
            .padding(.horizontal)
            
            // Save settings button
            Button(action: viewModel.saveSettings) {
                Text("Save Settings")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(moodEngine.currentMood.color)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func errorSection(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.red)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
    }
    
    private func mixtapePreviewSection(mixtape: MixTape) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generated Mixtape")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text(mixtape.title ?? "Untitled Mixtape")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let mood = mixtape.mood {
                    HStack {
                        Image(systemName: "music.note")
                        Text("Mood: \(mood)")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Text("\(mixtape.numberOfSongs) songs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                ForEach(mixtape.songsArray) { song in
                    SongRow(song: song)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            
            // Save button
            Button(action: saveMixtapeEnhanced) {
                Text("Save Mixtape")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.selectedMood?.color ?? moodEngine.currentMood.color)
                    .cornerRadius(10)
            }
        }
    }
    
    private var recentMixtapesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent AI Mixtapes")
                .font(.headline)
            
            ForEach(viewModel.recentMixtapes) { mixtape in
                NavigationLink(destination: MixTapeView(mixtape: mixtape)) {
                    MixtapeRow(mixtape: mixtape)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func generateMixtape() {
        haptics.prepare()
        isGenerating = true
        errorMessage = nil
        
        Task {
            do {
                try await viewModel.generateMixtape()
                haptics.notificationOccurred(.success)
            } catch {
                errorMessage = error.localizedDescription
                haptics.notificationOccurred(.error)
            }
            isGenerating = false
        }
    }
    
    private func saveMixtapeEnhanced() {
        let newMixtape = MixTape(context: moc)
        newMixtape.title = mixtapeName
        newMixtape.aiGenerated = true
        
        // Set mood tags
        if let mixtape = viewModel.currentMixtape {
            newMixtape.moodTags = mixtape.moodTags
            newMixtape.numberOfSongs = mixtape.numberOfSongs
            
            // Copy songs
            for song in mixtape.songsArray {
                let newSong = Song(context: moc)
                newSong.name = song.name
                newSong.moodTag = song.moodTag
                newSong.urlData = song.urlData
                newSong.mixTape = newMixtape
            }
        }
        
        do {
            try moc.save()
            
            // Post notification for MainTabView to handle navigation
            NotificationCenter.default.post(
                name: .mixtapeCreated,
                object: newMixtape
            )
            
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = "Error saving mixtape: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Views

struct SongRow: View {
    let song: Song
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(song.title ?? "Unknown Title")
                    .font(.body)
                
                Text(song.artist ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let mood = song.mood {
                Circle()
                    .fill(Mood(rawValue: mood)?.color ?? .gray)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MixtapeRow: View {
    let mixtape: MixTape
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(mixtape.title ?? "Untitled Mixtape")
                    .font(.headline)
                
                HStack {
                    if let mood = mixtape.mood {
                        Text(mood)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(mixtape.numberOfSongs) songs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - ViewModel

class AIGeneratedMixtapeViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published var songCount = 12
    @Published var selectedMood: Mood?
    @Published var currentMixtape: MixTape?
    @Published var recentMixtapes: [MixTape] = []
    @Published var generationProgress: Double = 0
    @Published var progressMessage = ""
    @Published var currentGenerationStep: String?
    @Published var showingError = false
    @Published var errorMessage: String?
    @Published var includeExplicitContent = false
    @Published var customMoodTag: String = ""
    
    private let moodEngine: MoodEngine
    private let personalityEngine: PersonalityEngine
    private let recommendationEngine: RecommendationEngine
    
    // Progress steps
    let generationSteps = [
        "Analyzing current mood and personality traits...",
        "Identifying musical preferences...",
        "Generating song recommendations...",
        "Applying mood-based filtering...",
        "Optimizing song order...",
        "Finalizing mixtape..."
    ]
    
    // MARK: - Initialization
    
    init(moodEngine: MoodEngine, personalityEngine: PersonalityEngine) {
        self.moodEngine = moodEngine
        self.personalityEngine = personalityEngine
        self.recommendationEngine = RecommendationEngine(
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        )
        
        loadRecentMixtapes()
    }
    
    // MARK: - Public Methods
    
    func generateMixtape() async throws {
        generationProgress = 0
        currentGenerationStep = generationSteps[0]
        progressMessage = "Starting mixtape generation..."
        
        // Use current or selected mood
        let targetMood = selectedMood ?? moodEngine.currentMood
        
        do {
            // Simulate progress through steps
            for (index, step) in generationSteps.enumerated() {
                await MainActor.run {
                    self.currentGenerationStep = step
                    self.progressMessage = "Phase \(index + 1) of \(generationSteps.count)"
                    self.generationProgress = Double(index) / Double(generationSteps.count)
                }
                
                // Simulate processing time for each step
                try await Task.sleep(nanoseconds: UInt64(0.5 * Double(NSEC_PER_SEC)))
            }
            
            let mixtape = try await recommendationEngine.generateMixtape(length: songCount)
            
            await MainActor.run {
                self.currentMixtape = mixtape
                self.recentMixtapes.insert(mixtape, at: 0)
                if self.recentMixtapes.count > 5 {
                    self.recentMixtapes.removeLast()
                }
                self.generationProgress = 1.0
                self.progressMessage = "Generation complete!"
                self.currentGenerationStep = "Mixtape ready!"
            }
            
        } catch {
            await MainActor.run {
                self.showingError = true
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    func saveSettings() {
        // Save explicit content preference and custom mood tag
        // This can be expanded to include other settings in the future
        UserDefaults.standard.set(includeExplicitContent, forKey: "includeExplicitContent")
        UserDefaults.standard.set(customMoodTag, forKey: "customMoodTag")
        
        // Provide feedback
        showingError = true
        errorMessage = "Settings saved!"
        
        // Optionally, you can trigger a mixtape regeneration with the new settings
        // Task {
        //     try await generateMixtape()
        // }
    }
    
    // MARK: - Private Methods
    
    private func loadRecentMixtapes() {
        let fetchRequest: NSFetchRequest<MixTape> = MixTape.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isAIGenerated == YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MixTape.createdDate, ascending: false)]
        fetchRequest.fetchLimit = 5
        
        do {
            recentMixtapes = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch recent mixtapes: \(error)")
        }
    }
}

// MARK: - Preview

struct AIGeneratedMixtapeView_Previews: PreviewProvider {
    static var previews: some View {
        AIGeneratedMixtapeView(
            moodEngine: MoodEngine(),
            personalityEngine: PersonalityEngine()
        )
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
