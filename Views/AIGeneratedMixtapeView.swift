//
//  AIGeneratedMixtapeView.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import SwiftUI
import CoreData
import AVKit

/// View for creating AI-generated mixtapes
struct AIGeneratedMixtapeView: View {
    @Environment(\.managedObjectContext) var moc
    @Environment(\.presentationMode) var presentationMode
    
    // AI service
    var aiService: AIIntegrationService
    
    // State for generation process
    @State private var generationType: MixtapeGenerationType = .mood
    @State private var generationStep: Int = 1
    @State private var isGenerating: Bool = false
    @State private var generationComplete: Bool = false
    @State private var generationProgress: Float = 0.0
    
    // State for mixtape details
    @State private var mixtapeName: String = ""
    @State private var selectedMood: Mood = .neutral
    @State private var selectedGenres: [String] = []
    @State private var songsCreated: [AIGeneratedSong] = []
    
    // Available genres (simulated list)
    let availableGenres = [
        "Rock", "Pop", "Hip-Hop", "R&B", "Jazz", "Classical", 
        "Electronic", "Folk", "Country", "Metal", "Indie", "Ambient"
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // Progress bar
                ProgressView(value: progressValue)
                    .progressViewStyle(LinearProgressViewStyle(tint: generationType.themeColor))
                    .padding(.horizontal)
                
                // Step indicators
                HStack {
                    ForEach(1...3, id: \.self) { step in
                        Text("Step \(step)")
                            .font(.caption)
                            .foregroundColor(step <= generationStep ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                
                // Step content
                if generationComplete {
                    generatedContentView
                } else if isGenerating {
                    generatingView
                } else {
                    // Step content based on current step
                    Group {
                        switch generationStep {
                        case 1:
                            mixtapeTypeView
                        case 2:
                            mixtapeDetailsView
                        case 3:
                            mixtapeConfirmationView
                        default:
                            EmptyView()
                        }
                    }
                    .transition(.opacity)
                }
                
                Spacer()
                
                // Bottom buttons
                if !isGenerating && !generationComplete {
                    HStack {
                        // Back button (except on first step)
                        if generationStep > 1 {
                            Button(action: {
                                withAnimation {
                                    generationStep -= 1
                                }
                            }) {
                                Text("Back")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                            }
                        }
                        
                        Spacer()
                        
                        // Next/Generate button
                        Button(action: {
                            if generationStep < 3 {
                                withAnimation {
                                    generationStep += 1
                                }
                            } else {
                                startGenerating()
                            }
                        }) {
                            Text(generationStep == 3 ? "Generate Mixtape" : "Next")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    generationType.themeColor.opacity(
                                        isNextButtonEnabled ? 1.0 : 0.5
                                    )
                                )
                                .cornerRadius(10)
                        }
                        .disabled(!isNextButtonEnabled)
                    }
                    .padding()
                }
                
                // Done button when complete
                if generationComplete {
                    Button(action: {
                        saveMixtape()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Save Mixtape")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(generationType.themeColor)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    .padding(.bottom)
                }
            }
            .navigationBarTitle("Create AI Mixtape", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                // Set default mixtape name based on mood
                updateDefaultMixtapeName()
                
                // Track interaction
                aiService.trackInteraction(type: "open_ai_mixtape_generator")
            }
        }
    }
    
    // MARK: - Component Views
    
    /// View for selecting the type of mixtape to generate
    var mixtapeTypeView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("What kind of mixtape would you like to create?")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(MixtapeGenerationType.allCases, id: \.self) { type in
                Button(action: {
                    generationType = type
                    updateDefaultMixtapeName()
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: type.icon)
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(type.themeColor)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(type.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        if generationType == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(type.themeColor)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(generationType == type ? type.themeColor : Color.clear, lineWidth: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    /// View for entering mixtape details based on selected type
    var mixtapeDetailsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Mixtape name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mixtape Name")
                        .font(.headline)
                    
                    TextField("Enter name", text: $mixtapeName)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                
                // Details based on generation type
                switch generationType {
                case .mood:
                    moodSelectionView
                case .genre:
                    genreSelectionView
                case .personality:
                    personalityBasedView
                }
                
                Spacer(minLength: 50)
            }
            .padding(.top)
        }
    }
    
    /// View for mood-based mixtape generation
    var moodSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select a Mood")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    Button(action: {
                        selectedMood = mood
                        
                        // Update mixtape name if it's still the default
                        if mixtapeName == getDefaultMixtapeName(for: generationType, with: selectedMood) {
                            updateDefaultMixtapeName()
                        }
                    }) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(selectedMood == mood ? mood.color : Color.gray.opacity(0.1))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: mood.systemIcon)
                                    .foregroundColor(selectedMood == mood ? .white : mood.color)
                            }
                            
                            Text(mood.rawValue)
                                .foregroundColor(selectedMood == mood ? mood.color : .primary)
                            
                            Spacer()
                            
                            if selectedMood == mood {
                                Image(systemName: "checkmark")
                                    .foregroundColor(mood.color)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedMood == mood ? mood.color : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            
            // Mood description
            if selectedMood != .neutral {
                Text(getMoodDescription(selectedMood))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedMood.color.opacity(0.1))
                    )
                    .padding(.horizontal)
            }
        }
    }
    
    /// View for genre-based mixtape generation
    var genreSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Genres (up to 3)")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(availableGenres, id: \.self) { genre in
                    Button(action: {
                        toggleGenre(genre)
                    }) {
                        HStack {
                            Text(genre)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedGenres.contains(genre) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(generationType.themeColor)
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    .frame(width: 24, height: 24)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedGenres.contains(genre) ? 
                                      generationType.themeColor.opacity(0.1) : Color.white)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
    
    /// View for personality-based mixtape generation
    var personalityBasedView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your music profile will be used")
                .font(.headline)
                .padding(.horizontal)
            
            // Personality traits from engine
            VStack(alignment: .leading, spacing: 12) {
                ForEach(aiService.personalityEngine.getPersonalityTraits(), id: \.type) { trait in
                    HStack {
                        Text(trait.type.rawValue)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        // Trait strength bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .fill(trait.type.themeColor)
                                    .frame(width: CGFloat(trait.value) * geometry.size.width, height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                        .frame(width: 150)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .padding(.horizontal)
            
            // Current mood
            HStack {
                Text("Current Mood:")
                    .font(.subheadline)
                
                HStack {
                    Image(systemName: aiService.moodEngine.currentMood.systemIcon)
                        .foregroundColor(aiService.moodEngine.currentMood.color)
                    
                    Text(aiService.moodEngine.currentMood.rawValue)
                        .foregroundColor(aiService.moodEngine.currentMood.color)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(aiService.moodEngine.currentMood.color.opacity(0.1))
                )
            }
            .padding(.horizontal)
            
            // Explanation of personality mixtape
            Text("AI will analyze your listening history, personality type, and current mood to create a personalized mixtape just for you.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                )
                .padding(.horizontal)
        }
    }
    
    /// View for confirming mixtape generation details
    var mixtapeConfirmationView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Confirm Your Mixtape")
                .font(.title2)
                .bold()
                .padding(.horizontal)
            
            // Mixtape summary card
            VStack(alignment: .leading, spacing: 16) {
                // Title
                HStack {
                    Text(mixtapeName)
                        .font(.headline)
                    
                    Spacer()
                    
                    // Edit button
                    Button(action: {
                        withAnimation {
                            generationStep = 2
                        }
                    }) {
                        Text("Edit")
                            .font(.subheadline)
                            .foregroundColor(generationType.themeColor)
                    }
                }
                
                Divider()
                
                // Details based on generation type
                switch generationType {
                case .mood:
                    HStack {
                        Text("Mood:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack {
                            Image(systemName: selectedMood.systemIcon)
                                .foregroundColor(selectedMood.color)
                            
                            Text(selectedMood.rawValue)
                                .foregroundColor(selectedMood.color)
                        }
                    }
                    
                case .genre:
                    HStack(alignment: .top) {
                        Text("Genres:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            ForEach(selectedGenres, id: \.self) { genre in
                                Text(genre)
                                    .font(.subheadline)
                            }
                        }
                    }
                    
                case .personality:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Personality:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(aiService.personalityEngine.currentPersonality.rawValue)
                                .font(.subheadline)
                        }
                        
                        HStack {
                            Text("Mood:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(aiService.moodEngine.currentMood.rawValue)
                                .font(.subheadline)
                        }
                    }
                }
                
                // Number of songs to generate
                HStack {
                    Text("Number of Songs:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("8-12")
                        .font(.subheadline)
                }
                
                Divider()
                
                // Disclaimer
                Text("AI-generated mixtapes create collections of song recommendations based on your selections. Results may vary based on your music library and listening history.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            )
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top)
    }
    
    /// View showing generation in progress
    var generatingView: some View {
        VStack(spacing: 24) {
            LottieAnimationView(animationName: "music_generation", loopMode: .loop)
                .frame(width: 200, height: 200)
            
            Text("Generating Your Mixtape")
                .font(.title2)
                .bold()
            
            Text(getGenerationStatusText())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Detailed progress
            ProgressView(value: generationProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: generationType.themeColor))
                .padding(.horizontal, 60)
            
            Text("\(Int(generationProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    /// View showing the generated mixtape
    var generatedContentView: some View {
        VStack(spacing: 20) {
            // Success icon
            ZStack {
                Circle()
                    .fill(generationType.themeColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(generationType.themeColor)
            }
            .padding(.top)
            
            Text("Mixtape Generated!")
                .font(.title2)
                .bold()
            
            Text("Your AI-generated mixtape is ready to be added to your collection")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // List of generated songs
            VStack(alignment: .leading) {
                Text("Songs:")
                    .font(.headline)
                    .padding(.horizontal)
                
                List {
                    ForEach(songsCreated, id: \.name) { song in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(song.name)
                                    .font(.headline)
                                
                                Text(song.artist)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if let mood = Mood(rawValue: song.mood) {
                                Image(systemName: mood.systemIcon)
                                    .foregroundColor(mood.color)
                            }
                        }
                    }
                }
                .frame(height: 300)
            }
        }
    }
    
    // MARK: - Helper Methods and Properties
    
    /// Progress value for the progress bar (0.0 - 1.0)
    var progressValue: Double {
        if generationComplete {
            return 1.0
        } else if isGenerating {
            return Double(generationProgress)
        } else {
            return Double(generationStep) / 3.0
        }
    }
    
    /// Whether the Next button should be enabled
    var isNextButtonEnabled: Bool {
        switch generationStep {
        case 1:
            // Type selection is always valid
            return true
        case 2:
            // Check if details are valid based on type
            if mixtapeName.isEmpty {
                return false
            }
            
            switch generationType {
            case .mood:
                return true // Any mood is valid, including neutral
            case .genre:
                return !selectedGenres.isEmpty && selectedGenres.count <= 3
            case .personality:
                return true // Personality is always valid
            }
        case 3:
            // Confirmation is always valid
            return true
        default:
            return false
        }
    }
    
    /// Toggle a genre in the selection
    private func toggleGenre(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.removeAll { $0 == genre }
        } else {
            // Limit to 3 genres
            if selectedGenres.count < 3 {
                selectedGenres.append(genre)
            }
        }
    }
    
    /// Get a description for a mood
    private func getMoodDescription(_ mood: Mood) -> String {
        switch mood {
        case .energetic:
            return "High-energy tracks with upbeat tempos and dynamic rhythms, perfect for workouts or when you need a boost."
        case .relaxed:
            return "Calming melodies and gentle progressions to help you unwind, de-stress, and create a peaceful atmosphere."
        case .happy:
            return "Uplifting, cheerful music with positive vibes that enhances good moods and brightens your day."
        case .melancholic:
            return "Reflective, emotional pieces that explore deeper feelings and provide a soundtrack for introspection."
        case .focused:
            return "Music that helps maintain concentration and productivity, with balanced patterns and minimal distractions."
        case .romantic:
            return "Intimate, emotional tracks that evoke feelings of love, connection, and warmth."
        case .angry:
            return "Intense, powerful music that helps process and channel strong emotions through cathartic expression."
        case .neutral:
            return "Balanced tracks that work well in various contexts without strongly evoking specific emotions."
        }
    }
    
    /// Get generation status text based on progress
    private func getGenerationStatusText() -> String {
        if generationProgress < 0.25 {
            return "Analyzing your preferences and selections..."
        } else if generationProgress < 0.5 {
            return "Finding the perfect musical elements..."
        } else if generationProgress < 0.75 {
            return "Curating song selections that match your criteria..."
        } else {
            return "Finalizing your personalized mixtape..."
        }
    }
    
    /// Start the mixtape generation process
    private func startGenerating() {
        isGenerating = true
        
        // Track interaction
        aiService.trackInteraction(type: "generate_ai_mixtape_\(generationType.rawValue)")
        
        // Simulate generation progress
        simulateGeneration()
    }
    
    /// Simulate the generation process with progress updates
    private func simulateGeneration() {
        generationProgress = 0.0
        
        // Create timer to update progress
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            // Increment progress
            withAnimation {
                generationProgress += Float.random(in: 0.01...0.03)
                
                // Check if complete
                if generationProgress >= 1.0 {
                    generationProgress = 1.0
                    timer.invalidate()
                    
                    // Generate songs
                    generateSongs()
                    
                    // Mark as complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            isGenerating = false
                            generationComplete = true
                        }
                    }
                }
            }
        }
        timer.fire()
    }
    
    /// Generate songs for the mixtape (simulated)
    private func generateSongs() {
        // Clear existing songs
        songsCreated.removeAll()
        
        // Number of songs to generate (random between 8-12)
        let songCount = Int.random(in: 8...12)
        
        // Generate songs based on type
        switch generationType {
        case .mood:
            generateMoodBasedSongs(count: songCount, mood: selectedMood)
        case .genre:
            generateGenreBasedSongs(count: songCount, genres: selectedGenres)
        case .personality:
            generatePersonalityBasedSongs(count: songCount)
        }
    }
    
    /// Generate mood-based songs
    private func generateMoodBasedSongs(count: Int, mood: Mood) {
        // Simulated song titles for different moods
        let moodSongTitles: [Mood: [String]] = [
            .energetic: [
                "Power Up", "Electric Energy", "Heart Rate", "Unstoppable Force",
                "Beyond Limits", "Maximum Drive", "Adrenaline Rush", "Dynamic Pulse",
                "Breaking Barriers", "Ignition", "Velocity", "Momentum", "Surge"
            ],
            .relaxed: [
                "Gentle Waves", "Calm Reflections", "Serene Horizons", "Peaceful Journey",
                "Quiet Moments", "Tranquil Spaces", "Soft Whispers", "Evening Calm",
                "Drifting Clouds", "Gentle Breeze", "Silent Sanctuary", "Floating"
            ],
            .happy: [
                "Sunshine Day", "Bright Horizons", "Joyful Moments", "Uplifted",
                "Smiling Skies", "Cheerful Heart", "Optimistic View", "Radiant",
                "Golden Hour", "Happy Place", "Blissful Feeling", "Vibrant Spirit"
            ],
            .melancholic: [
                "Silent Tears", "Fading Memories", "Rainy Reflections", "Distant Echo",
                "Bittersweet", "Nostalgia", "Autumn Leaves", "Longing Heart",
                "Quiet Sorrow", "Old Photographs", "Wistful Thinking", "Blue Evening"
            ],
            .focused: [
                "Clear Mind", "Steady Concentration", "Flow State", "Deep Focus",
                "Precision", "Mental Clarity", "Attention Stream", "Cognitive Space",
                "Thought Process", "Strategic Thinking", "Mindful Path", "Wavelength"
            ],
            .romantic: [
                "Heart's Desire", "Tender Moments", "Gentle Embrace", "Loving Touch",
                "Intimate Connection", "Passionate Whispers", "Heartbeat", "First Kiss",
                "Endless Love", "Sweet Surrender", "Moonlit Dance", "Devoted"
            ],
            .angry: [
                "Breaking Point", "Inner Fire", "Resistance", "Defiance",
                "Raw Energy", "Unleashed", "Intensity", "Raging Storm",
                "Primal Force", "Fierce Current", "Relentless", "Confrontation"
            ],
            .neutral: [
                "Balanced Perspective", "Middle Ground", "Even Flow", "Centered",
                "Steady State", "Equilibrium", "Natural Progression", "Basic Elements",
                "Fundamental", "Typical Day", "Normal Range", "Standard Process"
            ]
        ]
        
        // Simulated artists
        let artists = [
            "Skywave", "Echo Valley", "Pulse Collective", "The Resonance", 
            "Northern Lights", "Sonic Bloom", "Wavelength", "Harmonic Drift",
            "Rhythm Section", "Melody Makers", "Tonal Shift", "Sound Architects"
        ]
        
        // Generate songs
        for _ in 0..<count {
            let songTitles = moodSongTitles[mood] ?? moodSongTitles[.neutral]!
            let title = songTitles.randomElement()!
            let artist = artists.randomElement()!
            
            // Create song with primary mood, but some songs might have secondary moods
            let songMood = Float.random(in: 0...1) > 0.2 ? mood.rawValue : Mood.allCases.randomElement()!.rawValue
            
            songsCreated.append(
                AIGeneratedSong(
                    name: title,
                    artist: artist,
                    mood: songMood
                )
            )
        }
    }
    
    /// Generate genre-based songs
    private func generateGenreBasedSongs(count: Int, genres: [String]) {
        // Simulated song titles for different genres
        let genreSongTitles: [String: [String]] = [
            "Rock": [
                "Stone Cold", "Electric Heart", "Amplified", "Guitar Heroes", 
                "Stadium Anthem", "Power Chord", "Solid Ground", "Rock Formation",
                "Headbanger", "Distortion", "Feedback Loop", "Drum Break"
            ],
            "Pop": [
                "Summer Hit", "Radio Wave", "Catchy Chorus", "Dance Floor", 
                "Chart Topper", "Hook Line", "Melody Maker", "Perfect Beat",
                "Ear Candy", "Sing Along", "Infectious Groove", "Mainstream"
            ],
            "Hip-Hop": [
                "Flow State", "Wordplay", "Beat Drop", "Rhythm & Poetry", 
                "Urban Landscape", "Street Dreams", "Microphone Check", "Scratch That",
                "Beat Maker", "Rhyme Scheme", "Bass Line", "Freestyle"
            ],
            "R&B": [
                "Smooth Groove", "Soul Connection", "Heart & Soul", "Rhythm Nation", 
                "Emotional Truth", "Velvet Voice", "Midnight Mood", "Slow Jam",
                "Sweet Harmony", "Deep Feeling", "Love Language", "Soulful"
            ],
            "Jazz": [
                "Blue Note", "Improvisation", "Syncopation", "Midnight Session", 
                "Saxophone Dreams", "Piano Keys", "Trumpet Call", "Bass Walk",
                "Drum Solo", "Jazz Club", "Swing Time", "Cool Breeze"
            ],
            "Classical": [
                "Sonata No. 5", "Symphony in G", "Nocturne", "Moonlight Piece", 
                "String Quartet", "Piano Concerto", "Aria", "Etude in C Minor",
                "Fugue State", "Overture", "Adagio", "Cantabile"
            ],
            "Electronic": [
                "Digital Dreams", "Synthesized", "Circuit Break", "Bass Drop", 
                "Frequency", "Modulation", "Techno Logic", "Waveform",
                "Algorithm", "Cyber Space", "Drum Machine", "Electro Pulse"
            ],
            "Folk": [
                "Acoustic Story", "Campfire Tales", "Mountain Song", "River's Journey", 
                "Wooden Bridge", "Old Trail", "Farmer's Field", "Hometown",
                "Storyteller", "Simple Life", "Prairie Wind", "Valley Echo"
            ],
            "Country": [
                "Dusty Road", "Heartland", "Open Skies", "Small Town", 
                "Pickup Truck", "Western Sun", "Country Mile", "Saddle Up",
                "Honky Tonk", "Backroads", "Guitar Twang", "Whiskey River"
            ],
            "Metal": [
                "Iron Will", "Heavy Heart", "Double Bass", "Shredder", 
                "Thrash Master", "Dark Matter", "Headbanger's Ball", "Mosh Pit",
                "Power Surge", "Brutal Truth", "Extreme Measures", "Metal Core"
            ],
            "Indie": [
                "Alternative View", "Indie Spirit", "Garage Band", "Lo-Fi", 
                "Underground Scene", "DIY Ethic", "Vinyl Days", "Coffee Shop",
                "College Radio", "Indie Label", "Homemade", "Authentic"
            ],
            "Ambient": [
                "Atmospheric", "Spatial Awareness", "Environmental", "Background Texture", 
                "Soundscape", "Drone", "Minimal", "Ethereal",
                "Field Recording", "Organic Sounds", "Layered", "Textural"
            ]
        ]
        
        // Simulated artists for each genre
        let genreArtists: [String: [String]] = [
            "Rock": ["Stone Giants", "Electric Youth", "The Amplifiers", "Guitar Republic"],
            "Pop": ["Chart Toppers", "Radio Stars", "Melody Lane", "Pop Culture"],
            "Hip-Hop": ["Flow Masters", "Word Poets", "Beat Droppers", "Rhyme Time"],
            "R&B": ["Soul Sisters", "Rhythm Kings", "Smooth Operators", "Velvet Voices"],
            "Jazz": ["Blue Note Quartet", "Midnight Jazz Ensemble", "Saxophone Dreams", "Cool Trio"],
            "Classical": ["Chamber Orchestra", "Symphony No. 5", "Piano Virtuoso", "String Theory"],
            "Electronic": ["Digital Dreamers", "Circuit Breakers", "Synth Wave", "Electronic Pulse"],
            "Folk": ["Mountain Singers", "Acoustic Tales", "River Band", "Old Trail Trio"],
            "Country": ["Dusty Roads", "Heartland Express", "Western Skies", "Small Town Heroes"],
            "Metal": ["Iron Will", "Heavy Hearts", "Thrash Masters", "Metal Surge"],
            "Indie": ["Alternative Scene", "Garage Band Heroes", "Lo-Fi Lovers", "Coffee Shop Orchestra"],
            "Ambient": ["Atmospheric Ensemble", "Spatial Sound Design", "Environmental Audio", "Texture Lab"]
        ]
        
        // Moods that often match each genre
        let genreMoods: [String: [Mood]] = [
            "Rock": [.energetic, .angry, .neutral],
            "Pop": [.happy, .energetic, .romantic],
            "Hip-Hop": [.energetic, .focused, .angry],
            "R&B": [.romantic, .melancholic, .relaxed],
            "Jazz": [.relaxed, .focused, .romantic],
            "Classical": [.focused, .melancholic, .relaxed],
            "Electronic": [.energetic, .focused, .neutral],
            "Folk": [.relaxed, .melancholic, .neutral],
            "Country": [.melancholic, .relaxed, .neutral],
            "Metal": [.angry, .energetic, .focused],
            "Indie": [.melancholic, .relaxed, .happy],
            "Ambient": [.relaxed, .focused, .neutral]
        ]
        
        // Generate songs
        for _ in 0..<count {
            // Pick a random genre from selected genres
            let genre = genres.randomElement()!
            
            // Get song titles and artists for this genre
            let titles = genreSongTitles[genre] ?? genreSongTitles["Pop"]!
            let artists = genreArtists[genre] ?? genreArtists["Pop"]!
            let moods = genreMoods[genre] ?? [.neutral]
            
            let title = titles.randomElement()!
            let artist = artists.randomElement()!
            let mood = moods.randomElement()!
            
            songsCreated.append(
                AIGeneratedSong(
                    name: title,
                    artist: artist,
                    mood: mood.rawValue
                )
            )
        }
    }
    
    /// Generate personality-based songs
    private func generatePersonalityBasedSongs(count: Int) {
        // Get the user's personality and mood
        let personality = aiService.personalityEngine.currentPersonality
        let mood = aiService.moodEngine.currentMood
        
        // For personality-based songs, we'll create a mix that reflects both
        // personality traits and current mood
        
        // Blend of artists that align with different personality types
        let personalityArtists: [PersonalityType: [String]] = [
            .explorer: ["Discovery Channel", "New Frontiers", "The Wanderers", "Horizon Chasers"],
            .curator: ["Collection Masters", "The Organizers", "Quality Control", "Curated Sound"],
            .enthusiast: ["Deep Dive", "Expert Level", "The Specialists", "Passionate Players"],
            .social: ["Friend Circle", "The Sharers", "Community Sound", "Social Network"],
            .ambient: ["Background Beats", "Passive Players", "Ambient Flow", "Soundtrack Masters"],
            .analyzer: ["Technical Detail", "Sound Engineers", "Audio Analysis", "Structure Masters"]
        ]
        
        // Create a mix of songs based on personality and mood
        for i in 0..<count {
            // Alternate between personality-focused and mood-focused tracks
            let isPrimaryMood = i % 2 == 0
            
            let title: String
            let artist: String
            let songMood: Mood
            
            if isPrimaryMood {
                // Create mood-based song
                let moodTitles = [
                    "\(mood.rawValue) Journey", 
                    "\(mood.rawValue) Moment", 
                    "Feeling \(mood.rawValue)", 
                    "\(mood.rawValue) Vibes"
                ]
                title = moodTitles.randomElement()!
                artist = "Mood Masters"
                songMood = mood
            } else {
                // Create personality-based song
                let personalityTitles = [
                    "\(personality.rawValue)'s Path", 
                    "The \(personality.rawValue)", 
                    "\(personality.rawValue) Style", 
                    "\(personality.rawValue) Profile"
                ]
                title = personalityTitles.randomElement()!
                artist = personalityArtists[personality]?.randomElement() ?? "Personality Project"
                
                // Mix of user's current mood and random moods
                songMood = Float.random(in: 0...1) > 0.5 ? mood : Mood.allCases.randomElement()!
            }
            
            songsCreated.append(
                AIGeneratedSong(
                    name: title,
                    artist: artist,
                    mood: songMood.rawValue
                )
            )
        }
    }
    
    /// Update the default mixtape name based on generation type and mood
    private func updateDefaultMixtapeName() {
        mixtapeName = getDefaultMixtapeName(for: generationType, with: selectedMood)
    }
    
    /// Get a default mixtape name based on type and mood
    private func getDefaultMixtapeName(for type: MixtapeGenerationType, with mood: Mood) -> String {
        switch type {
        case .mood:
            return "\(mood.rawValue) Mix"
        case .genre:
            if selectedGenres.isEmpty {
                return "Genre Mix"
            } else if selectedGenres.count == 1 {
                return "\(selectedGenres[0]) Collection"
            } else {
                return "Multi-Genre Mix"
            }
        case .personality:
            return "Personal Mix for \(aiService.personalityEngine.currentPersonality.rawValue)"
        }
    }
    
    /// Save the generated mixtape to CoreData
    private func saveMixtape() {
        // Create new mixtape
        let newMixtape = MixTape(context: moc)
        newMixtape.title = mixtapeName
        newMixtape.aiGenerated = true
        
        // Set mood tags based on songs
        let songMoods = songsCreated.map { $0.mood }
        let uniqueMoods = Array(Set(songMoods))
        newMixtape.moodTags = uniqueMoods.joined(separator: ", ")
        
        // Save the number of songs (this would normally be the actual songs)
        newMixtape.numberOfSongs = Int16(songsCreated.count)
        
        // In a real app, we would create actual Song entities here
        // and add them to the mixtape
        
        // Save changes
        do {
            try moc.save()
            
            // Track interaction
            aiService.trackInteraction(type: "save_ai_generated_mixtape")
        } catch {
            print("Error saving AI mixtape: \(error)")
        }
    }
}

/// Types of mixtape generation
enum MixtapeGenerationType: String, CaseIterable {
    case mood = "mood"
    case genre = "genre"
    case personality = "personality"
    
    var title: String {
        switch self {
        case .mood: return "Mood-Based Mixtape"
        case .genre: return "Genre-Based Mixtape"
        case .personality: return "Personality Mixtape"
        }
    }
    
    var description: String {
        switch self {
        case .mood: return "Create a mixtape that matches a specific mood or emotion"
        case .genre: return "Build a mixtape around your favorite musical genres"
        case .personality: return "Let AI analyze your music profile for a personalized mixtape"
        }
    }
    
    var icon: String {
        switch self {
        case .mood: return "waveform.path.ecg"
        case .genre: return "guitars"
        case .personality: return "person.crop.rectangle"
        }
    }
    
    var themeColor: Color {
        switch self {
        case .mood: return Color.purple
        case .genre: return Color.blue
        case .personality: return Color.green
        }
    }
}

/// Model for an AI-generated song
struct AIGeneratedSong {
    let name: String
    let artist: String
    let mood: String
}

/// Simple animation view for loading states
struct LottieAnimationView: View {
    let animationName: String
    let loopMode: LoopMode
    
    enum LoopMode {
        case loop
        case playOnce
    }
    
    var body: some View {
        // In a real implementation, this would use Lottie or another animation library
        // For now, we'll simulate with a built-in animation
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 150, height: 150)
            
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .opacity(0.6)
                .rotationEffect(.degrees(360))
                .animation(
                    Animation.linear(duration: 2)
                        .repeatForever(autoreverses: false),
                    value: UUID()
                )
            
            ForEach(0..<3) { i in
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 60 + CGFloat(i * 30), height: 60 + CGFloat(i * 30))
                    .opacity(0.6)
                    .scaleEffect(0.8)
                    .animation(
                        Animation.easeInOut(duration: 1.5 + Double(i) * 0.2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                        value: UUID()
                    )
            }
        }
        .onAppear { } // Trigger animations
    }
}
