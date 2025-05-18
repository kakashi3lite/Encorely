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
                VStack(spacing: 20) {
                    // Header with current mood and personality
                    headerSection
                    
                    // Generation controls
                    controlsSection
                    
                    // Progress or error message
                    if isGenerating {
                        progressSection
                    } else if let error = errorMessage {
                        errorSection(message: error)
                    }
                    
                    // Generated mixtape preview
                    if let mixtape = viewModel.currentMixtape {
                        mixtapePreviewSection(mixtape: mixtape)
                    }
                    
                    // Recent mixtapes
                    recentMixtapesSection
                }
                .padding()
            }
            .navigationTitle("AI Mixtape Generator")
            .sheet(isPresented: $showingMoodPicker) {
                MoodPickerView(mood: $viewModel.selectedMood)
            }
            .sheet(isPresented: $showingPersonalityView) {
                PersonalityView(personality: personalityEngine.currentPersonality)
            }
            .alert("Generation Failed", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error occurred")
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Current mood card
            Button(action: { showingMoodPicker = true }) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current Mood")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(moodEngine.currentMood.rawValue)
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(moodEngine.currentMood.color)
                        .frame(width: 30, height: 30)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            
            // Personality type card
            Button(action: { showingPersonalityView = true }) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Music Personality")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(personalityEngine.currentPersonality.rawValue)
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    Image(systemName: personalityEngine.currentPersonality.icon)
                        .foregroundColor(personalityEngine.currentPersonality.themeColor)
                        .font(.title2)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Mixtape name input
            TextField("Mixtape Name", text: $mixtapeName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            // Song count picker
            Stepper(
                "Number of Songs: \(viewModel.songCount)",
                value: $viewModel.songCount,
                in: 5...20
            )
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            
            // Generate button
            Button(action: generateMixtape) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Generate AI Mixtape")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(moodEngine.currentMood.color)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            .disabled(isGenerating)
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            // Animated progress ring with percentage
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.generationProgress))
                    .stroke(moodEngine.currentMood.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.generationProgress)
                
                Text("\(Int(viewModel.generationProgress * 100))%")
                    .font(.headline)
                    .foregroundColor(moodEngine.currentMood.color)
            }
            .padding(.vertical, 8)
            
            // Stage indicator
            Text(viewModel.progressMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut, value: viewModel.progressMessage)
            
            // Detailed status message
            if let currentStep = viewModel.currentGenerationStep {
                Text(currentStep)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .animation(.easeInOut, value: currentStep)
            }
        }
        .padding()
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
    
    private let moodEngine: MoodEngine
    private let personalityEngine: PersonalityEngine
    private let recommendationEngine: RecommendationEngine
    
    // Progress steps
    private let generationSteps = [
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
