//
//  InsightsDashboardView.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import SwiftUI
import CoreData

/// Dashboard view showing insights about user's music library and listening habits
struct InsightsDashboardView: View {
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: MixTape.entity(), sortDescriptors: [
        NSSortDescriptor(keyPath: \MixTape.lastPlayedDate, ascending: false)
    ]) var mixTapes: FetchedResults<MixTape>
    
    // AI service
    var aiService: AIIntegrationService
    
    // State
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showMoodDetails: Bool = false
    @State private var isLoadingInsights: Bool = true
    @State private var insights: LibraryInsights = LibraryInsights()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Time range selector
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: selectedTimeRange) { _ in
                        refreshInsights()
                    }
                    
                    if isLoadingInsights {
                        // Loading state
                        ProgressView("Analyzing your library...")
                            .padding(.top, 40)
                    } else {
                        // Insights content
                        Group {
                            // Top section: Mood Distribution
                            InsightSectionView(title: "Your Music Mood Profile", systemImage: "waveform.path.ecg") {
                                VStack(spacing: 16) {
                                    // Mood distribution chart
                                    HStack(spacing: 0) {
                                        ForEach(insights.moodDistribution.sorted(by: { $0.value > $1.value }), id: \.key) { mood, percentage in
                                            if let mood = Mood(rawValue: mood), percentage > 0 {
                                                Rectangle()
                                                    .fill(mood.color)
                                                    .frame(width: CGFloat(percentage) * UIScreen.main.bounds.width * 0.8, height: 24)
                                                    .overlay(
                                                        Text(percentage > 0.1 ? "\(Int(percentage * 100))%" : "")
                                                            .font(.caption)
                                                            .foregroundColor(.white)
                                                            .padding(.horizontal, 4)
                                                    )
                                            }
                                        }
                                    }
                                    .cornerRadius(6)
                                    .padding(.horizontal)
                                    
                                    // Mood breakdown
                                    if showMoodDetails {
                                        VStack(spacing: 12) {
                                            ForEach(insights.moodDistribution.sorted(by: { $0.value > $1.value }), id: \.key) { mood, percentage in
                                                if let mood = Mood(rawValue: mood), percentage > 0 {
                                                    HStack {
                                                        Image(systemName: mood.systemIcon)
                                                            .foregroundColor(mood.color)
                                                            .frame(width: 24)
                                                        
                                                        Text(mood.rawValue)
                                                            .font(.subheadline)
                                                        
                                                        Spacer()
                                                        
                                                        Text("\(Int(percentage * 100))%")
                                                            .font(.subheadline)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    .padding(.horizontal)
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Show/Hide details button
                                    Button(action: {
                                        withAnimation {
                                            showMoodDetails.toggle()
                                        }
                                    }) {
                                        Label(
                                            showMoodDetails ? "Hide Details" : "Show Details",
                                            systemImage: showMoodDetails ? "chevron.up" : "chevron.down"
                                        )
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            
                            // Most played mixtapes
                            InsightSectionView(title: "Most Played Mixtapes", systemImage: "chart.bar.fill") {
                                VStack(spacing: 16) {
                                    ForEach(insights.topMixtapes, id: \.title) { mixtape in
                                        HStack {
                                            Text(mixtape.title)
                                                .font(.subheadline)
                                            
                                            Spacer()
                                            
                                            Text("\(mixtape.playCount) plays")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal)
                                    }
                                    
                                    if insights.topMixtapes.isEmpty {
                                        Text("No play data available yet")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding()
                                    }
                                }
                            }
                            
                            // Listening patterns
                            InsightSectionView(title: "Listening Patterns", systemImage: "clock") {
                                VStack(spacing: 16) {
                                    // Time of day chart
                                    DayHourHeatmap(data: insights.listeningTimeDistribution)
                                        .frame(height: 120)
                                        .padding(.horizontal)
                                    
                                    // Legend
                                    HStack {
                                        Text("Less")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Rectangle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [.blue.opacity(0.1), .blue]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(height: 8)
                                            .cornerRadius(4)
                                        
                                        Text("More")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                    
                                    // Peak listening time
                                    if let peakTime = insights.peakListeningTime {
                                        HStack {
                                            Image(systemName: "clock.fill")
                                                .foregroundColor(.blue)
                                            
                                            Text("Peak listening time: \(peakTime)")
                                                .font(.subheadline)
                                        }
                                    }
                                }
                            }
                            
                            // AI-powered recommendations
                            InsightSectionView(title: "AI Recommendations", systemImage: "wand.and.stars") {
                                VStack(spacing: 16) {
                                    ForEach(insights.recommendations, id: \.title) { recommendation in
                                        HStack(alignment: .top) {
                                            Image(systemName: recommendation.icon)
                                                .foregroundColor(.purple)
                                                .frame(width: 24)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(recommendation.title)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                
                                                Text(recommendation.description)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // Personality insights
                            InsightSectionView(title: "Your Music Personality", systemImage: "person.crop.circle") {
                                VStack(spacing: 16) {
                                    // Current personality
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Primary Type")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            Text(aiService.personalityEngine.currentPersonality.rawValue)
                                                .font(.headline)
                                                .foregroundColor(aiService.personalityEngine.currentPersonality.themeColor)
                                        }
                                        
                                        Spacer()
                                        
                                        // Icon
                                        Image(systemName: getPersonalityIcon(aiService.personalityEngine.currentPersonality))
                                            .font(.system(size: 40))
                                            .foregroundColor(aiService.personalityEngine.currentPersonality.themeColor.opacity(0.8))
                                    }
                                    .padding(.horizontal)
                                    
                                    // Description
                                    Text(getPersonalityDescription(aiService.personalityEngine.currentPersonality))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                        .padding(.horizontal)
                                    
                                    // Personality traits
                                    VStack(spacing: 8) {
                                        ForEach(aiService.personalityEngine.getPersonalityTraits(), id: \.type) { trait in
                                            HStack {
                                                Text(trait.type.rawValue)
                                                    .font(.caption)
                                                    .frame(width: 80, alignment: .leading)
                                                
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
                                                
                                                Text("\(Int(trait.value * 100))%")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 40)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                }
                            }
                        }
                    }
                    
                    // Refresh button
                    Button(action: {
                        refreshInsights()
                    }) {
                        Label("Refresh Insights", systemImage: "arrow.clockwise")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .padding(.top)
            }
            .navigationBarTitle("Music Insights", displayMode: .large)
            .onAppear {
                // Load insights when view appears
                refreshInsights()
                
                // Track interaction
                aiService.trackInteraction(type: "view_insights_dashboard")
            }
        }
    }
    
    // Refresh insights data
    private func refreshInsights() {
        isLoadingInsights = true
        
        // Simulate delay for analysis
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Generate insights
            insights = generateInsights()
            isLoadingInsights = false
            
            // Track interaction
            aiService.trackInteraction(type: "refresh_insights_\(selectedTimeRange.rawValue)")
        }
    }
    
    // Generate insights from the music library
    private func generateInsights() -> LibraryInsights {
        // In a real app, this would analyze actual user data
        // This is a simulation for demonstration purposes
        
        var insights = LibraryInsights()
        
        // Generate mood distribution
        let moodDistribution = generateMoodDistribution()
        insights.moodDistribution = moodDistribution
        
        // Generate top mixtapes
        insights.topMixtapes = generateTopMixtapes()
        
        // Generate listening time distribution
        insights.listeningTimeDistribution = generateListeningTimeDistribution()
        insights.peakListeningTime = "7:00 PM - 9:00 PM"
        
        // Generate AI recommendations
        insights.recommendations = generateRecommendations()
        
        return insights
    }
    
    // Generate simulated mood distribution
    private func generateMoodDistribution() -> [String: Float] {
        var distribution: [String: Float] = [:]
        
        // Get a list of all moods
        let allMoods = Mood.allCases
        
        // Set dominant mood based on AI service
        let dominantMood = aiService.moodEngine.currentMood
        distribution[dominantMood.rawValue] = Float.random(in: 0.25...0.40)
        
        // Distribute remaining percentages
        var remaining = 1.0 - (distribution[dominantMood.rawValue] ?? 0)
        let otherMoods = allMoods.filter { $0 != dominantMood }
        
        for mood in otherMoods {
            // Randomly decide if this mood gets a percentage
            if Bool.random() && remaining > 0 {
                let value = Float.random(in: 0.02...min(0.20, remaining))
                distribution[mood.rawValue] = value
                remaining -= value
            }
        }
        
        // Add remaining to dominant
        distribution[dominantMood.rawValue] = (distribution[dominantMood.rawValue] ?? 0) + remaining
        
        return distribution
    }
    
    // Generate top mixtapes
    private func generateTopMixtapes() -> [MixtapePlayCount] {
        var playCountData: [MixtapePlayCount] = []
        
        // Use actual mixtape data if available
        if mixTapes.count > 0 {
            for (index, mixtape) in mixTapes.prefix(5).enumerated() {
                let playCount = 20 - (index * 3) + Int.random(in: 0...5)
                playCountData.append(
                    MixtapePlayCount(
                        title: mixtape.wrappedTitle,
                        playCount: playCount
                    )
                )
            }
        } else {
            // Fallback to simulated data
            playCountData = [
                MixtapePlayCount(title: "Workout Mix", playCount: 23),
                MixtapePlayCount(title: "Study Session", playCount: 17),
                MixtapePlayCount(title: "Evening Relaxation", playCount: 12),
                MixtapePlayCount(title: "Morning Commute", playCount: 8),
                MixtapePlayCount(title: "Weekend Vibes", playCount: 5)
            ]
        }
        
        return playCountData.sorted { $0.playCount > $1.playCount }
    }
    
    // Generate listening time distribution (heatmap data)
    private func generateListeningTimeDistribution() -> [[Float]] {
        // 7 days (rows) x 24 hours (columns)
        var data: [[Float]] = Array(repeating: Array(repeating: 0.0, count: 24), count: 7)
        
        // Generate patterns based on common listening habits
        for day in 0..<7 {
            for hour in 0..<24 {
                // Morning commute (weekdays)
                if day < 5 && (hour >= 7 && hour <= 9) {
                    data[day][hour] = Float.random(in: 0.3...0.7)
                }
                
                // Evening commute/workout (weekdays)
                if day < 5 && (hour >= 17 && hour <= 19) {
                    data[day][hour] = Float.random(in: 0.5...1.0)
                }
                
                // Late night (weekends)
                if (day == 5 || day == 6) && (hour >= 20 || hour <= 2) {
                    data[day][hour] = Float.random(in: 0.4...0.9)
                }
                
                // Afternoon (weekends)
                if (day == 5 || day == 6) && (hour >= 14 && hour <= 18) {
                    data[day][hour] = Float.random(in: 0.3...0.8)
                }
                
                // Low activity hours
                if hour >= 2 && hour <= 5 {
                    data[day][hour] = Float.random(in: 0.0...0.2)
                }
                
                // Add some randomness
                data[day][hour] += Float.random(in: 0.0...0.3)
                data[day][hour] = min(data[day][hour], 1.0)
            }
        }
        
        return data
    }
    
    // Generate AI recommendations
    private func generateRecommendations() -> [AIRecommendation] {
        // Personalize recommendations based on mood and personality
        let currentMood = aiService.moodEngine.currentMood
        let personality = aiService.personalityEngine.currentPersonality
        
        var recommendations: [AIRecommendation] = []
        
        // Recommendation based on current mood
        recommendations.append(
            AIRecommendation(
                title: "Create a \(currentMood.rawValue) Mixtape",
                description: "Based on your current mood, we recommend creating a mixtape that enhances your \(currentMood.rawValue.lowercased()) feelings.",
                icon: currentMood.systemIcon
            )
        )
        
        // Recommendation based on personality
        switch personality {
        case .explorer:
            recommendations.append(
                AIRecommendation(
                    title: "Discover New Genres",
                    description: "Your explorer personality would enjoy branching out into new musical territories this week.",
                    icon: "safari"
                )
            )
        case .curator:
            recommendations.append(
                AIRecommendation(
                    title: "Organize Your Collection",
                    description: "Consider adding mood tags to your existing mixtapes for better organization.",
                    icon: "folder.badge.plus"
                )
            )
        case .enthusiast:
            recommendations.append(
                AIRecommendation(
                    title: "Deep Dive Playlist",
                    description: "Create a focused collection highlighting a single artist or genre you love.",
                    icon: "arrow.down.circle"
                )
            )
        case .social:
            recommendations.append(
                AIRecommendation(
                    title: "Share Your Top Mixtape",
                    description: "Your 'Evening Relaxation' mixtape would be perfect to share with friends.",
                    icon: "square.and.arrow.up"
                )
            )
        case .ambient:
            recommendations.append(
                AIRecommendation(
                    title: "Background Sound Enhancement",
                    description: "Try the new mood-based crossfade feature for smoother transitions between songs.",
                    icon: "waveform"
                )
            )
        case .analyzer:
            recommendations.append(
                AIRecommendation(
                    title: "Analyze Audio Features",
                    description: "Explore the detailed audio analysis view to understand the technical aspects of your music.",
                    icon: "waveform.path.ecg.rectangle"
                )
            )
        }
        
        // Time-based recommendation
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 17 && hour <= 22 {
            recommendations.append(
                AIRecommendation(
                    title: "Evening Wind Down",
                    description: "It's evening time - a perfect moment for a relaxing playlist to transition from work to rest.",
                    icon: "moon.stars"
                )
            )
        } else if hour >= 6 && hour <= 10 {
            recommendations.append(
                AIRecommendation(
                    title: "Morning Energy Boost",
                    description: "Start your day right with an energizing playlist to get you moving.",
                    icon: "sunrise"
                )
            )
        }
        
        return recommendations
    }
    
    // Get icon for personality type
    private func getPersonalityIcon(_ type: PersonalityType) -> String {
        switch type {
        case .explorer: return "safari"
        case .curator: return "folder"
        case .enthusiast: return "star"
        case .social: return "person.2"
        case .ambient: return "waveform"
        case .analyzer: return "chart.bar"
        }
    }
    
    // Get detailed description for personality type
    private func getPersonalityDescription(_ type: PersonalityType) -> String {
        switch type {
        case .explorer:
            return "As an Explorer, you enjoy discovering new music and seeking fresh experiences. You're more likely to try different genres and are excited by novelty in your listening habits."
        case .curator:
            return "Your Curator personality loves organizing and perfecting your music collections. You value quality and structure in your library and take pride in creating well-crafted mixtapes."
        case .enthusiast:
            return "As an Enthusiast, you tend to deep-dive into artists and genres you love. You appreciate the details and history behind your music and enjoy immersive listening experiences."
        case .social:
            return "Your Social personality values music as a way to connect with others. You enjoy sharing discoveries and creating mixtapes that bring people together through shared musical experiences."
        case .ambient:
            return "As an Ambient listener, you primarily enjoy music as a backdrop to your daily activities. You value seamless playback experiences and mood-appropriate selections."
        case .analyzer:
            return "Your Analyzer personality appreciates the technical aspects of music. You enjoy exploring audio features, production details, and the structural elements of your collection."
        }
    }
}

/// Section view for insights dashboard
struct InsightSectionView<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content
    
    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Content
            content
                .padding(.bottom, 16)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

/// Heatmap view for time-based data visualization
struct DayHourHeatmap: View {
    let data: [[Float]] // 7 days x 24 hours
    let daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Hours labels (show only a few for clarity)
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 40)
                
                ForEach([0, 6, 12, 18, 23], id: \.self) { hour in
                    Text("\(hour)")
                        .font(.system(size: 8))
                        .frame(maxWidth: .infinity)
                }
            }
            .foregroundColor(.secondary)
            
            // Day rows
            ForEach(0..<7, id: \.self) { day in
                HStack(spacing: 0) {
                    // Day label
                    Text(daysOfWeek[day])
                        .font(.caption)
                        .frame(width: 40)
                        .foregroundColor(.secondary)
                    
                    // Hour cells
                    ForEach(0..<24, id: \.self) { hour in
                        Rectangle()
                            .fill(Color.blue.opacity(Double(data[day][hour])))
                            .frame(height: 12)
                    }
                }
            }
        }
    }
}

/// Time range selection for insights
enum TimeRange: String, CaseIterable {
    case week = "week"
    case month = "month"
    case year = "year"
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

/// Model for library insights
struct LibraryInsights {
    var moodDistribution: [String: Float] = [:]
    var topMixtapes: [MixtapePlayCount] = []
    var listeningTimeDistribution: [[Float]] = []
    var peakListeningTime: String?
    var recommendations: [AIRecommendation] = []
}

/// Model for mixtape play count
struct MixtapePlayCount {
    let title: String
    let playCount: Int
}

/// Model for AI recommendation
struct AIRecommendation {
    let title: String
    let description: String
    let icon: String
}
