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
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overview header
                HStack {
                    TimeframeSelector(selection: $selectedTimeframe)
                    Spacer()
                    refreshButton
                }
                .padding(.horizontal)
                
                // High-level metrics
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    MetricCard(
                        title: "Total Listening Time",
                        value: metrics?.totalListeningTime ?? "0h",
                        icon: "clock",
                        color: .blue
                    )
                    
                    MetricCard(
                        title: "Mixtapes Created",
                        value: "\(metrics?.mixtapesCreated ?? 0)",
                        icon: "music.note.list",
                        color: .purple
                    )
                    
                    MetricCard(
                        title: "AI Suggestions Used",
                        value: "\(metrics?.aiSuggestionsUsed ?? 0)",
                        icon: "brain",
                        color: .green
                    )
                    
                    MetricCard(
                        title: "Mood Changes",
                        value: "\(metrics?.moodChanges ?? 0)",
                        icon: "heart.fill",
                        color: aiService.moodEngine.currentMood.color
                    )
                }
                .padding(.horizontal)
                
                // Mood distribution chart
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
                
                // Listening habits chart
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
                
                // AI-generated insights carousel
                if let insights = metrics?.aiInsights {
                    InsightsCarousel(insights: insights)
                        .padding(.horizontal)
                }
                
                // Quick actions
                VStack(alignment: .leading) {
                    Text("Quick Actions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            QuickActionButton(
                                title: "Manage Siri Shortcuts",
                                icon: "waveform",
                                action: { showingSiriShortcuts = true }
                            )
                            
                            QuickActionButton(
                                title: "Generate Weekly Report",
                                icon: "doc.text.below.ecg",
                                action: generateWeeklyReport
                            )
                            
                            QuickActionButton(
                                title: "Analyze Library",
                                icon: "magnifyingglass.circle",
                                action: analyzeLibrary
                            )
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Insights")
        .sheet(isPresented: $showingSiriShortcuts) {
            SiriShortcutsView(aiService: aiService)
        }
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - Components
    
    private var refreshButton: some View {
        Button(action: refreshData) {
            Image(systemName: "arrow.clockwise")
                .rotationEffect(.degrees(refreshing ? 360 : 0))
        }
        .disabled(refreshing)
    }
    
    // MARK: - Helper Functions
    
    private func loadData() {
        // Load insights data
        refreshing = true
        // Implement data loading
        refreshing = false
    }
    
    private func refreshData() {
        loadData()
    }
    
    private func generateWeeklyReport() {
        // Implement report generation
    }
    
    private func analyzeLibrary() {
        // Implement library analysis
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

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }
}

struct InsightsCarousel: View {
    let insights: [AIInsight]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("AI Insights")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(insights) { insight in
                        InsightCard(insight: insight)
                    }
                }
            }
        }
    }
}

struct InsightCard: View {
    let insight: AIInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: insight.icon)
                    .foregroundColor(insight.color)
                Text(insight.title)
                    .font(.headline)
            }
            
            Text(insight.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(width: 300)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
