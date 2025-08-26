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
    
    private let haptics = UINotificationFeedbackGenerator()
    
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
                    // Header with mood and personality cards
                    moodPersonalityHeaderSection
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Current settings")
                    
                    // Configuration and generation controls
                    if !isGenerating {
                        configurationSection
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Mixtape configuration")
                        
                        if viewModel.currentMixtape == nil {
                            generateButtonSection
                                .accessibilityHint("Create a new AI-generated mixtape with the selected settings")
                        }
                    }
                    
                    // Progress, error or preview
                    Group {
                        if isGenerating {
                            progressSection
                                .accessibilityElement(children: .contain)
                                .accessibilityLabel("Generation progress")
                                .accessibilityValue("\(Int(viewModel.generationProgress * 100))% complete")
                                .accessibilityAddTraits(.updatesFrequently)
                        } else if let error = errorMessage {
                            errorSection(message: error)
                                .accessibilityLabel("Generation error")
                        } else if let mixtape = viewModel.currentMixtape {
                            mixtapePreviewSection(mixtape: mixtape)
                                .accessibilityElement(children: .contain)
                                .accessibilityLabel("Generated mixtape preview")
                        }
                    }
                    
                    // Recent mixtapes section
                    if !viewModel.recentMixtapes.isEmpty && !isGenerating {
                        recentMixtapesSection
                            .accessibilityElement(children: .contain)
                            .accessibilityLabel("Recent AI mixtapes")
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Create AI Mixtape")
        }
    }
    
    // MARK: - View Components
    
    private var moodPersonalityHeaderSection: some View {
        VStack(spacing: 24) {
            // Mood card
            Button(action: { showingMoodPicker = true }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Current Mood")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: moodEngine.currentMood.systemIcon)
                            .foregroundColor(moodEngine.currentMood.color)
                    }
                    
                    Text(moodEngine.currentMood.rawValue)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: moodEngine.currentMood.color.opacity(0.1), radius: 10)
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current mood: \(moodEngine.currentMood.rawValue)")
            .accessibilityHint("Double tap to change your mood")
            .accessibilityAddTraits([.isButton])
            
            // Personality type card
            Button(action: { showingPersonalityView = true }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Personality")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: personalityEngine.currentPersonality.icon)
                            .foregroundColor(personalityEngine.currentPersonality.themeColor)
                    }
                    
                    Text(personalityEngine.currentPersonality.rawValue)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: personalityEngine.currentPersonality.themeColor.opacity(0.1), radius: 10)
                )
            }
            .accessibilityElement(children: .combine) 
            .accessibilityLabel("Music personality: \(personalityEngine.currentPersonality.rawValue)")
            .accessibilityHint("Double tap to change your music personality type")
            .accessibilityAddTraits([.isButton])
        }
    }
    
    private var configurationSection: some View {
        VStack(spacing: 16) {
            // Mixtape name
            HStack {
                TextField("Mixtape Name", text: $mixtapeName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityLabel("Mixtape name")
                
                Button(action: { showingNameSuggestions = true }) {
                    Image(systemName: "wand.stars")
                        .foregroundColor(moodEngine.currentMood.color)
                }
                .accessibilityLabel("Get name suggestions")
                .accessibilityHint("Generate AI suggestions for mixtape names")
            }
            .padding(.horizontal)
            
            // Song count stepper
            VStack(alignment: .leading, spacing: 4) {
                Text("Number of songs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Stepper(
                    value: $viewModel.songCount,
                    in: 5...20
                ) {
                    Text("\(viewModel.songCount)")
                        .font(.headline)
                }
                .accessibilityLabel("Number of songs")
                .accessibilityValue("\(viewModel.songCount) songs")
                .accessibilityHint("Adjust the number of songs in the mixtape")
            }
            
            Divider()
            
            // Duration picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Duration")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Duration", selection: $viewModel.duration) {
                    Text("30 min").tag(30)
                    Text("45 min").tag(45)
                    Text("60 min").tag(60)
                }
                .pickerStyle(SegmentedPickerStyle())
                .accessibilityLabel("Mixtape duration")
                .accessibilityValue("\(viewModel.duration) minutes")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var generateButtonSection: some View {
        Button(action: generateMixtape) {
            Text("Generate Mixtape")
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(moodEngine.currentMood.color)
                )
        }
        .accessibilityLabel("Generate mixtape")
        .accessibilityHint("Double tap to create a new mixtape with your selected preferences")
        .padding(.horizontal)
    }
    
    private var progressSection: some View {
        VStack(spacing: 20) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.generationProgress))
                    .stroke(moodEngine.currentMood.color, style: StrokeStyle(
                        lineWidth: 10,
                        lineCap: .round
                    ))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(Int(viewModel.generationProgress * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(viewModel.currentGenerationStep ?? "Processing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Generation progress")
            .accessibilityValue("\(Int(viewModel.generationProgress * 100))% complete, \(viewModel.currentGenerationStep ?? "Processing...")")
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
    
    private func errorSection(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            Text("Generation Error")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: {
                withAnimation {
                    errorMessage = nil
                    generateMixtape()
                }
            }) {
                Text("Try Again")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 5)
        .padding()
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
    
    private var advancedOptionsSection: some View {
        VStack(spacing: 16) {
            // Explicit content toggle
            Toggle("Include explicit content", isOn: $viewModel.includeExplicitContent)
                .toggleStyle(SwitchToggleStyle(tint: moodEngine.currentMood.color))
                .accessibilityLabel("Include explicit content")
                .accessibilityHint("Double tap to \(viewModel.includeExplicitContent ? "exclude" : "include") explicit content")
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
                    .accessibilityLabel("Custom mood tag")
                    .accessibilityHint("Enter a custom tag to describe the mood of your mixtape")
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
            .accessibilityLabel("Save settings")
            .accessibilityHint("Double tap to save your advanced settings")
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var generationProgressSection: some View {
        VStack(spacing: 16) {
            // Progress indicator
            CircularProgressView(progress: viewModel.generationProgress)
                .frame(width: 100, height: 100)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Generation progress")
                .accessibilityValue("\(Int(viewModel.generationProgress * 100))%")
                .accessibilityAddTraits(.updatesFrequently)
            
            // Status text
            Text(viewModel.generationPhase)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityLabel("Current phase")
                .accessibilityValue(viewModel.generationPhase)
            
            // Cancel button
            Button(action: cancelGeneration) {
                Text("Cancel")
                    .foregroundColor(.red)
                    .padding()
            }
            .accessibilityLabel("Cancel generation")
            .accessibilityHint("Double tap to stop generating the mixtape")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mixtape generation progress")
    }
    
    // MARK: - Actions
    
    private func generateMixtape() {
        haptics.prepare()
        withAnimation {
            isGenerating = true
            errorMessage = nil
        }
        
        Task {
            do {
                try await viewModel.generateMixtape()
                haptics.notificationOccurred(.success)
            } catch {
                withAnimation {
                    errorMessage = error.localizedDescription
                }
                haptics.notificationOccurred(.error)
            }
            withAnimation {
                isGenerating = false
            }
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
    @Published var duration = 45
    @Published var selectedMood: Mood?
    @Published var currentMixtape: MixTape?
    @Published var recentMixtapes: [MixTape] = []
    @Published var generationProgress: Double = 0
    @Published var currentGenerationStep: String?
    @Published var progressMessage = ""
    @Published var showingError = false
    @Published var errorMessage: String?
    @Published var includeExplicitContent = false
    @Published var customMoodTag = ""
    
    private let moodEngine: MoodEngine
    private let personalityEngine: PersonalityEngine
    private let recommendationEngine: RecommendationEngine
    
    // Generation step definitions with weights
    private struct GenerationStep {
        let message: String
        let weight: Double // Percentage of total progress
        let minimumDuration: TimeInterval // Minimum time this step should take
    }
    
    private let generationSteps = [
        GenerationStep(
            message: "Analyzing current mood and personality traits...",
            weight: 0.15,
            minimumDuration: 1.0
        ),
        GenerationStep(
            message: "Identifying musical preferences...",
            weight: 0.2,
            minimumDuration: 1.5
        ),
        GenerationStep(
            message: "Generating song recommendations...",
            weight: 0.3,
            minimumDuration: 2.0
        ),
        GenerationStep(
            message: "Applying mood-based filtering...",
            weight: 0.15,
            minimumDuration: 1.0
        ),
        GenerationStep(
            message: "Optimizing song order...",
            weight: 0.1,
            minimumDuration: 0.75
        ),
        GenerationStep(
            message: "Finalizing mixtape...",
            weight: 0.1,
            minimumDuration: 0.75
        )
    ]
    
    // Progress tracking
    private var progressCancellable: AnyCancellable?
    private var currentStepIndex = 0
    private var stepProgress: Double = 0
    
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
    
    // MARK: - Generation Methods
    
    @MainActor
    func generateMixtape() async throws {
        // Reset progress
        currentStepIndex = 0
        stepProgress = 0
        generationProgress = 0
        showingError = false
        errorMessage = nil
        currentMixtape = nil
        
        do {
            // Progress through each step
            for (index, step) in generationSteps.enumerated() {
                currentStepIndex = index
                currentGenerationStep = step.message
                
                // Create async sequence for smooth progress animation
                let progressSequence = Timer.publish(every: 0.05, on: .main, in: .common)
                    .autoconnect()
                    .map { _ in min(self.stepProgress + 0.05, 1.0) }
                
                progressCancellable = progressSequence.sink { [weak self] progress in
                    self?.updateProgress(stepProgress: progress)
                }
                
                // Simulate step processing with minimum duration
                try await Task.sleep(nanoseconds: UInt64(step.minimumDuration * 1_000_000_000))
                
                // Ensure step appears complete
                stepProgress = 1.0
                updateProgress(stepProgress: 1.0)
                
                progressCancellable?.cancel()
                
                // Check for cancellation between steps
                try Task.checkCancellation()
            }
            
            // Generate the actual mixtape
            let mixtape = try await recommendationEngine.generateMixtape(length: songCount)
            
            // Update UI with result
            currentMixtape = mixtape
            recentMixtapes.insert(mixtape, at: 0)
            if recentMixtapes.count > 5 {
                recentMixtapes.removeLast()
            }
            
            // Ensure progress appears complete
            generationProgress = 1.0
            currentGenerationStep = "Mixtape ready!"
            
        } catch is CancellationError {
            throw GenerationError.cancelled
        } catch {
            showingError = true
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    @MainActor
    private func updateProgress(stepProgress: Double) {
        // Calculate overall progress based on step weights
        var totalProgress = 0.0
        
        for i in 0..<currentStepIndex {
            totalProgress += generationSteps[i].weight
        }
        
        totalProgress += generationSteps[currentStepIndex].weight * stepProgress
        generationProgress = totalProgress
    }
    
    private func loadRecentMixtapes() {
        let fetchRequest: NSFetchRequest<MixTape> = MixTape.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "aiGenerated == YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MixTape.createdDate, ascending: false)]
        fetchRequest.fetchLimit = 5
        
        do {
            recentMixtapes = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch recent mixtapes: \(error)")
        }
    }
    
    func saveSettings() {
        // Here you can add code to handle saving of advanced settings if needed
        print("Settings saved: Include Explicit Content - \(includeExplicitContent), Custom Mood Tag - \(customMoodTag)")
    }
}

// MARK: - Errors

enum GenerationError: LocalizedError {
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Generation was cancelled"
        }
    }
}
