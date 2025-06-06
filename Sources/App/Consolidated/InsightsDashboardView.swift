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
    // MARK: - Properties
    
    var aiService: AIIntegrationService
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(entity: MixTape.entity(), sortDescriptors: []) var mixtapes: FetchedResults<MixTape>
    
    @State private var selectedTimeframe: TimeFrame = .week
    @State private var showingSiriShortcuts = false
    @State private var refreshing = false
    @State private var metrics: InsightMetrics?
    @State private var selectedTab = 0
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overview metrics
                HStack {
                    TimeframeSelector(selection: $selectedTimeframe)
                    Spacer()
                    refreshButton
                }
                .padding(.horizontal)
                
                // Key metrics cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    MetricCard(
                        title: "Total Listening Time",
                        value: metrics?.totalListeningTime ?? "0h",
                        icon: "clock",
                        color: .blue
                    )
                    
                    MetricCard(
                        title: "Favorite Mood",
                        value: metrics?.topMood ?? "N/A",
                        icon: "heart.fill",
                        color: .pink
                    )
                    
                    MetricCard(
                        title: "Mixtapes Created",
                        value: "\(metrics?.mixtapesCreated ?? 0)",
                        icon: "music.note.list",
                        color: .purple
                    )
                    
                    MetricCard(
                        title: "Songs Added",
                        value: "\(metrics?.songsAdded ?? 0)",
                        icon: "plus.circle",
                        color: .green
                    )
                }
                .padding(.horizontal)
                
                // Mood distribution
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mood Distribution")
                        .font(.headline)
                    
                    MoodDistributionChart(data: metrics?.moodDistribution ?? [:])
                        .frame(height: 200)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 2)
                .padding(.horizontal)
                
                // Listening habits
                VStack(alignment: .leading, spacing: 12) {
                    Text("Listening Habits")
                        .font(.headline)
                    
                    ListeningHabitsChart(data: metrics?.listeningHabits ?? [:])
                        .frame(height: 200)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 2)
                .padding(.horizontal)
                
                // AI-generated insights
                if let insights = metrics?.aiInsights {
                    InsightsCarousel(insights: insights)
                        .padding(.horizontal)
                }
                
                // Siri shortcuts section
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.blue)
                        Text("Voice Commands")
                            .font(.headline)
                        Spacer()
                        Button(action: { showingSiriShortcuts = true }) {
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
                .cornerRadius(16)
                .shadow(radius: 2)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Your Music Insights")
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingSiriShortcuts) {
            SiriShortcutsView(aiService: aiService)
        }
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - Supporting Views
    
    struct TimeframeSelector: View {
        @Binding var selection: TimeFrame
        
        var body: some View {
            Picker("Timeframe", selection: $selection) {
                ForEach(TimeFrame.allCases) { timeframe in
                    Text(timeframe.description)
                        .tag(timeframe)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    struct MetricCard: View {
        let title: String
        let value: String
        let icon: String
        let color: Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: color.opacity(0.1), radius: 5)
        }
    }
    
    struct MoodDistributionChart: View {
        let data: [String: Double]
        
        var body: some View {
            Chart {
                ForEach(Array(data.keys.sorted()), id: \.self) { mood in
                    BarMark(
                        x: .value("Mood", mood),
                        y: .value("Percentage", data[mood] ?? 0)
                    )
                    .foregroundStyle(getMoodColor(mood))
                }
            }
        }
        
        private func getMoodColor(_ mood: String) -> Color {
            Mood(rawValue: mood)?.color ?? .gray
        }
    }
    
    struct ListeningHabitsChart: View {
        let data: [String: Int]
        
        var body: some View {
            Chart {
                ForEach(Array(data.keys.sorted()), id: \.self) { hour in
                    LineMark(
                        x: .value("Hour", hour),
                        y: .value("Listens", data[hour] ?? 0)
                    )
                    .foregroundStyle(.blue)
                }
            }
        }
    }
    
    struct InsightsCarousel: View {
        let insights: [String]
        @State private var selectedIndex = 0
        
        var body: some View {
            TabView(selection: $selectedIndex) {
                ForEach(insights.indices, id: \.self) { index in
                    InsightCard(text: insights[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .frame(height: 160)
        }
    }
    
    struct InsightCard: View {
        let text: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                Text(text)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 2)
        }
    }
    
    private var refreshButton: some View {
        Button(action: refreshData) {
            Image(systemName: refreshing ? "hourglass" : "arrow.clockwise")
                .imageScale(.large)
                .rotationEffect(.degrees(refreshing ? 0 : 360))
                .animation(
                    refreshing ? 
                        Animation.linear(duration: 1).repeatForever(autoreverses: false) : 
                        .default,
                    value: refreshing
                )
        }
        .disabled(refreshing)
    }
    
    // MARK: - Actions
    
    private func loadData() {
        refreshData()
    }
    
    private func refreshData() {
        refreshing = true
        
        // Simulate data loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            metrics = InsightMetrics(
                totalListeningTime: "12h",
                topMood: "Happy",
                mixtapesCreated: mixtapes.count,
                songsAdded: getTotalSongs(),
                moodDistribution: generateMoodDistribution(),
                listeningHabits: generateListeningHabits(),
                aiInsights: generateInsights()
            )
            refreshing = false
        }
    }
    
    private func getTotalSongs() -> Int {
        mixtapes.reduce(0) { $0 + $1.songsArray.count }
    }
    
    private func generateMoodDistribution() -> [String: Double] {
        var distribution: [String: Double] = [:]
        let moods = Mood.allCases
        
        for mood in moods {
            distribution[mood.rawValue] = Double.random(in: 0...100)
        }
        
        return distribution
    }
    
    private func generateListeningHabits() -> [String: Int] {
        var habits: [String: Int] = [:]
        
        for hour in 0..<24 {
            habits[String(format: "%02d:00", hour)] = Int.random(in: 0...50)
        }
        
        return habits
    }
    
    private func generateInsights() -> [String] {
        [
            "You listen to more upbeat music in the morning",
            "Your favorite mood this week is Happy",
            "You've created 3 new mixtapes this week",
            "Try exploring more relaxing music for evening sessions"
        ]
    }
}

// MARK: - Supporting Types

struct InsightMetrics {
    let totalListeningTime: String
    let topMood: String
    let mixtapesCreated: Int
    let songsAdded: Int
    let moodDistribution: [String: Double]
    let listeningHabits: [String: Int]
    let aiInsights: [String]
}

enum TimeFrame: String, CaseIterable, Identifiable {
    case day = "24H"
    case week = "7D"
    case month = "30D"
    case year = "1Y"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .day: return "24 Hours"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

// MARK: - Preview

struct InsightsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        InsightsDashboardView(aiService: AIIntegrationService())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
