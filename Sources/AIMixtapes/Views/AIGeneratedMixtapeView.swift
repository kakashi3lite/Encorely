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
                    
                    // Configuration and generation controls
                    if !isGenerating {
                        configurationSection
                        
                        if viewModel.currentMixtape == nil {
                            generateButtonSection
                        }
                    }
                    
                    // Progress, error or preview
                    Group {
                        if isGenerating {
                            progressSection
                                .transition(.opacity)
                        } else if let error = errorMessage {
                            errorSection(message: error)
                                .transition(.opacity)
                        } else if let mixtape = viewModel.currentMixtape {
                            mixtapePreviewSection(mixtape: mixtape)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut, value: isGenerating)
                    .animation(.easeInOut, value: errorMessage)
                    .animation(.easeInOut, value: viewModel.currentMixtape)
                    
                    // Recent mixtapes section
                    if !viewModel.recentMixtapes.isEmpty && !isGenerating {
                        recentMixtapesSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Create AI Mixtape")
            .background(Color(.systemGroupedBackground))
        }
        .overlay(
            // Loading overlay
            ZStack {
                if isGenerating {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: isGenerating)
        )
    }
    
    // MARK: - View Components
    
    private var moodPersonalityHeaderSection: some View {
        HStack(spacing: 16) {
            // Current mood card
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
            .buttonStyle(PlainButtonStyle())
            
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
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
    }
    
    private var configurationSection: some View {
        VStack(spacing: 20) {
            TextField("Mixtape Name", text: $mixtapeName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            // Song count and duration
            HStack(spacing: 16) {
                // Song count stepper
                VStack(alignment: .leading, spacing: 4) {
                    Text("Songs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Stepper(
                        value: $viewModel.songCount,
                        in: 5...20
                    ) {
                        Text("\(viewModel.songCount)")
                            .font(.headline)
                    }
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
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    private var generateButtonSection: some View {
        Button(action: generateMixtape) {
            HStack {
                Image(systemName: "wand.and.stars")
                Text("Generate AI Mixtape")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(mixtapeName.isEmpty ? Color.gray : moodEngine.currentMood.color)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(mixtapeName.isEmpty)
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
                    .animation(.linear(duration: 0.2), value: viewModel.generationProgress)
                
                VStack {
                    Text("\(Int(viewModel.generationProgress * 100))%")
                        .font(.title2)
                        .bold()
                    Text(viewModel.currentGenerationStep ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            // Progress steps
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(viewModel.generationSteps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 12) {
                        // Step indicator
                        Circle()
                            .fill(index <= Int(viewModel.generationProgress * Float(viewModel.generationSteps.count)) ? 
                                moodEngine.currentMood.color : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                        
                        // Step text
                        Text(step)
                            .font(.subheadline)
                            .foregroundColor(index <= Int(viewModel.generationProgress * Float(viewModel.generationSteps.count)) ? 
                                .primary : .secondary)
                        
                        // Loading indicator for current step
                        if index == Int(viewModel.generationProgress * Float(viewModel.generationSteps.count)) {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            
            // Cancel button
            Button("Cancel") {
                withAnimation {
                    isGenerating = false
                    viewModel.generationProgress = 0
                    viewModel.currentGenerationStep = nil
                }
            }
            .foregroundColor(.secondary)
            .padding(.top)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 5)
        .padding()
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
