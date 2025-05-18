//
//  InsightsDashboardView.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import SwiftUI
import CoreData
import Charts

struct InsightsDashboardView: View {
    @Environment(\.managedObjectContext) var moc
    @ObservedObject var aiService: AIIntegrationService
    @ObservedObject var moodEngine: MoodEngine
    @ObservedObject var personalityEngine: PersonalityEngine
    @StateObject private var viewModel = InsightsViewModel()
    @State private var showingSiriShortcuts = false
    
    // Fetch all mixtapes
    @FetchRequest(
        entity: MixTape.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \MixTape.title, ascending: true)]
    ) var mixtapes: FetchedResults<MixTape>
    
    // State
    @State private var selectedTimeRange: TimeRange = .week
    @State private var isLoading = true
    @State private var refreshing = false
    @State private var currentError: AppError?
    @State private var retryAction: (() -> Void)?
    
    // Computed metrics
    private var totalListeningTime: TimeInterval {
        mixtapes.reduce(0) { $0 + $1.totalPlayTime }
    }
    
    private var averageDailyListening: TimeInterval {
        totalListeningTime / Double(selectedTimeRange.days)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Error banner if needed
                    if let error = currentError {
                        ErrorBanner(error: error) {
                            retryAction?()
                        }
                    }
                    
                    // Main content
                    if isLoading {
                        ProgressView("Analyzing your music...")
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        // Time range picker
                        Picker("Time Range", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases) { range in
                                Text(range.description).tag(range)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        // Overview metrics
                        overviewMetricsView
                        
                        // Mood distribution chart
                        moodDistributionView
                        
                        // Listening habits
                        listeningHabitsView
                        
                        // AI-generated insights
                        personalizedInsightsView
                        
                        // AI analytics visualization
                        aiAnalyticsView
                        
                        // Siri Shortcuts Section
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundColor(.blue)
                                Text("Voice Commands")
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    showingSiriShortcuts = true
                                }) {
                                    Text("Manage")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            
                            if aiService.siriIntegrationEnabled {
                                Text("Use Siri to control your music by mood and create AI mixtapes hands-free.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            } else {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text("Enable Siri in Settings to use voice commands")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 2)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Your Music Insights")
            .navigationBarItems(trailing: refreshButton)
            .onAppear(perform: loadData)
            .withErrorHandling()
        }
        .sheet(isPresented: $showingSiriShortcuts) {
            SiriShortcutsView(aiService: aiService)
        }
    }
    
    // MARK: - Subviews
    
    private var refreshButton: some View {
        Button(action: refreshData) {
            Image(systemName: refreshing ? "hourglass" : "arrow.clockwise")
                .imageScale(.large)
                .rotationEffect(.degrees(refreshing ? 0 : 360))
                .animation(refreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: refreshing)
        }
        .disabled(refreshing)
    }
    
    private var overviewMetricsView: some View {
        VStack(spacing: 16) {
            HStack {
                MetricCard(
                    title: "Total Listening",
                    value: formatDuration(totalListeningTime),
                    icon: "headphones",
                    color: .blue
                )
                
                MetricCard(
                    title: "Daily Average",
                    value: formatDuration(averageDailyListening),
                    icon: "clock",
                    color: .green
                )
            }
            
            HStack {
                MetricCard(
                    title: "Mixtapes",
                    value: "\(mixtapes.count)",
                    icon: "music.note.list",
                    color: .purple
                )
                
                MetricCard(
                    title: "Total Songs",
                    value: "\(totalSongs)",
                    icon: "music.note",
                    color: .orange
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var moodDistributionView: some View {
        VStack(alignment: .leading) {
            Text("Mood Distribution")
                .font(.headline)
                .padding(.horizontal)
            
            if moodDistribution.isEmpty {
                Text("Not enough mood data")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                Chart {
                    ForEach(moodDistribution, id: \.mood) { item in
                        BarMark(
                            x: .value("Mood", item.mood.rawValue),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(item.mood.color)
                    }
                }
                .frame(height: 200)
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private var listeningHabitsView: some View {
        VStack(alignment: .leading) {
            Text("Listening Habits")
                .font(.headline)
                .padding(.horizontal)
            
            if listeningHabits.isEmpty {
                Text("Not enough listening data")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                Chart {
                    ForEach(listeningHabits, id: \.hour) { item in
                        LineMark(
                            x: .value("Hour", item.hour),
                            y: .value("Listens", item.listens)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 200)
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private var personalizedInsightsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Insights")
                .font(.headline)
                .padding(.horizontal)
            
            Text(aiService.getUserInsights())
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private var aiAnalyticsView: some View {
        VStack(spacing: 24) {
            // Current Personality Card
            PersonalityCard(personality: personalityEngine.currentPersonality)
            
            // Mood History Chart
            ChartSection(
                title: "Mood Patterns",
                subtitle: "Your emotional journey through music"
            ) {
                Chart(viewModel.moodHistory) { entry in
                    LineMark(
                        x: .value("Time", entry.date),
                        y: .value("Value", entry.value)
                    )
                    .foregroundStyle(by: .value("Mood", entry.mood.rawValue))
                }
                .chartLegend(position: .bottom)
                .frame(height: 200)
            }
            
            // Genre Distribution
            ChartSection(
                title: "Genre Preferences",
                subtitle: "Based on your listening patterns"
            ) {
                Chart(viewModel.genreStats) { entry in
                    SectorMark(
                        angle: .value("Count", entry.count),
                        innerRadius: .ratio(0.6),
                        angularInset: 1
                    )
                    .foregroundStyle(by: .value("Genre", entry.genre))
                }
                .frame(height: 200)
            }
            
            // AI Insights Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(viewModel.aiInsights) { insight in
                    InsightCard(insight: insight)
                }
            }
            
            // Mood Impact Analysis
            ChartSection(
                title: "Mood Impact",
                subtitle: "How music affects your emotional state"
            ) {
                HStack {
                    ForEach(viewModel.moodImpacts) { impact in
                        VStack {
                            Text(impact.mood.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ZStack(alignment: .bottom) {
                                Rectangle()
                                    .fill(impact.mood.color.opacity(0.2))
                                    .frame(width: 30, height: 100)
                                
                                Rectangle()
                                    .fill(impact.mood.color)
                                    .frame(width: 30, height: CGFloat(impact.value * 100))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Text("\(Int(impact.value * 100))%")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            viewModel.loadInsights()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadData() {
        isLoading = true
        
        do {
            try calculateMoodDistribution()
            try calculateListeningHabits()
            isLoading = false
        } catch {
            currentError = AppError.loadFailure(error)
            retryAction = loadData
            isLoading = false
        }
    }
    
    private func refreshData() {
        refreshing = true
        
        Task {
            do {
                // Simulate network delay
                try await Task.sleep(nanoseconds: 1_500_000_000)
                
                try calculateMoodDistribution()
                try calculateListeningHabits()
                
                refreshing = false
            } catch {
                currentError = AppError.loadFailure(error)
                retryAction = refreshData
                refreshing = false
            }
        }
    }
    
    private func calculateMoodDistribution() throws {
        var distribution: [Mood: Int] = [:]
        
        for mixtape in mixtapes {
            guard let moodString = mixtape.moodTags,
                  let mood = Mood(rawValue: moodString) else {
                continue
            }
            distribution[mood, default: 0] += 1
        }
        
        if distribution.isEmpty {
            throw AppError.insufficientData
        }
        
        moodDistribution = distribution.map { MoodData(mood: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private func calculateListeningHabits() throws {
        var habits: [Int: Int] = [:]
        
        // Get play events from the last selectedTimeRange.days
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: now) ?? now
        
        // Fetch play events (simulated)
        let events = mixtapes.flatMap { mixtape -> [Date] in
            let playCount = Int(mixtape.playCount)
            return (0..<playCount).map { _ in
                calendar.date(byAdding: .hour,
                            value: -.random(in: 0...selectedTimeRange.days * 24),
                            to: now) ?? now
            }
        }
        .filter { $0 >= startDate }
        
        // Group by hour
        for date in events {
            let hour = calendar.component(.hour, from: date)
            habits[hour, default: 0] += 1
        }
        
        if habits.isEmpty {
            throw AppError.insufficientData
        }
        
        listeningHabits = (0...23).map { hour in
            HourlyListening(hour: hour, listens: habits[hour] ?? 0)
        }
    }
    
    private var totalSongs: Int {
        mixtapes.reduce(0) { $0 + Int($1.numberOfSongs) }
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        if hours > 0 {
            return "\(hours)h"
        } else {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Types

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

enum TimeRange: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30
    case quarter = 90
    
    var id: Int { rawValue }
    var days: Int { rawValue }
    
    var description: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "3 Months"
        }
    }
}

struct MoodData {
    let mood: Mood
    let count: Int
}

struct HourlyListening {
    let hour: Int
    let listens: Int
}

// MARK: - Preview
struct InsightsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let aiService = AIIntegrationService(context: context)
        
        InsightsDashboardView(aiService: aiService, moodEngine: MoodEngine(), personalityEngine: PersonalityEngine())
            .environment(\.managedObjectContext, context)
    }
}

// MARK: - Supporting Views

struct ChartSection<Content: View>: View {
    let title: String
    let subtitle: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
            
            content()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct PersonalityCard: View {
    let personality: PersonalityType
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: personality.icon)
                .font(.system(size: 40))
                .foregroundColor(personality.themeColor)
            
            Text(personality.rawValue)
                .font(.title2)
                .fontWeight(.medium)
            
            Text(personality.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack {
                ForEach(personality.traits) { trait in
                    Text(trait.name)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(personality.themeColor.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct InsightCard: View {
    let insight: AIInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: insight.icon)
                    .foregroundColor(insight.color)
                Text(insight.title)
                    .font(.headline)
            }
            
            Text(insight.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            if let recommendation = insight.recommendation {
                Text(recommendation)
                    .font(.caption)
                    .padding(8)
                    .background(insight.color.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - View Model

class InsightsViewModel: ObservableObject {
    @Published var moodHistory: [MoodEntry] = []
    @Published var genreStats: [GenreStat] = []
    @Published var aiInsights: [AIInsight] = []
    @Published var moodImpacts: [MoodImpact] = []
    
    func loadInsights() {
        // Load mood history
        moodHistory = generateMoodHistory()
        
        // Load genre statistics
        genreStats = generateGenreStats()
        
        // Generate AI insights
        aiInsights = generateAIInsights()
        
        // Calculate mood impacts
        moodImpacts = generateMoodImpacts()
    }
    
    // MARK: - Data Generation
    
    private func generateMoodHistory() -> [MoodEntry] {
        let moods: [Mood] = [.happy, .energetic, .relaxed, .melancholic]
        return (0..<20).map { index in
            let date = Calendar.current.date(byAdding: .day, value: -index, to: Date())!
            return MoodEntry(
                date: date,
                mood: moods.randomElement()!,
                value: Double.random(in: 0.3...0.9)
            )
        }.reversed()
    }
    
    private func generateGenreStats() -> [GenreStat] {
        [
            GenreStat(genre: "Rock", count: 35),
            GenreStat(genre: "Pop", count: 25),
            GenreStat(genre: "Jazz", count: 20),
            GenreStat(genre: "Classical", count: 15),
            GenreStat(genre: "Electronic", count: 5)
        ]
    }
    
    private func generateAIInsights() -> [AIInsight] {
        [
            AIInsight(
                title: "Peak Focus Time",
                description: "You're most productive when listening to classical music in the morning",
                icon: "brain.head.profile",
                color: .purple,
                recommendation: "Try starting your day with Bach or Mozart"
            ),
            AIInsight(
                title: "Mood Booster",
                description: "Upbeat pop music significantly improves your mood",
                icon: "sparkles",
                color: .yellow,
                recommendation: "Create an energizing morning playlist"
            )
        ]
    }
    
    private func generateMoodImpacts() -> [MoodImpact] {
        [
            MoodImpact(mood: .happy, value: 0.8),
            MoodImpact(mood: .energetic, value: 0.6),
            MoodImpact(mood: .relaxed, value: 0.7),
            MoodImpact(mood: .melancholic, value: 0.4)
        ]
    }
}

// MARK: - Data Models

struct MoodEntry: Identifiable {
    let id = UUID()
    let date: Date
    let mood: Mood
    let value: Double
}

struct GenreStat: Identifiable {
    let id = UUID()
    let genre: String
    let count: Double
}

struct AIInsight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
    let recommendation: String?
}

struct MoodImpact: Identifiable {
    let id = UUID()
    let mood: Mood
    let value: Double
}

// MARK: - Previews

struct InsightsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            InsightsDashboardView(
                moodEngine: MoodEngine(),
                personalityEngine: PersonalityEngine()
            )
        }
    }
}
