import SwiftUI

struct PodcastsTabView: View {
    var aiService: AIIntegrationService
    @State private var podcasts: [Podcast] = []
    @State private var isLoading = true
    @State private var selectedFilter = PodcastFilter.recommended
    @State private var searchText = ""
    
    enum PodcastFilter: String, CaseIterable {
        case recommended = "For You"
        case trending = "Trending"
        case newReleases = "New"
        case subscribed = "Library"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(PodcastFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter,
                                color: aiService.moodEngine.currentMood.color
                            ) {
                                withAnimation {
                                    selectedFilter = filter
                                }
                                aiService.trackInteraction(type: "podcast_filter_\(filter.rawValue.lowercased())")
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Featured podcast
                if let featured = podcasts.first {
                    FeaturedPodcastCard(
                        podcast: featured,
                        mood: aiService.moodEngine.currentMood
                    )
                    .padding(.horizontal)
                }
                
                // Mood-based recommendations
                VStack(alignment: .leading, spacing: 12) {
                    Text("Based on your \(aiService.moodEngine.currentMood.rawValue) mood")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(podcasts.prefix(5), id: \.id) { podcast in
                                PodcastCard(
                                    title: podcast.title,
                                    host: podcast.host,
                                    coverImage: podcast.coverImage,
                                    mood: aiService.moodEngine.currentMood
                                )
                                .frame(width: 220)
                                .onTapGesture {
                                    aiService.trackInteraction(type: "select_podcast", metadata: ["id": podcast.id])
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Latest episodes
                VStack(alignment: .leading, spacing: 12) {
                    Text("Latest Episodes")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(podcasts.flatMap { $0.episodes.prefix(3) }, id: \.id) { episode in
                            PodcastEpisodeRow(
                                title: episode.title,
                                podcast: episode.podcastTitle,
                                duration: episode.duration,
                                aiService: aiService
                            )
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .overlay(Group {
            if isLoading {
                ProgressView("Loading podcasts...")
                    .progressViewStyle(.circular)
                    .tint(aiService.moodEngine.currentMood.color)
            }
        })
        .onAppear {
            loadPodcasts()
        }
    }
    
    private func loadPodcasts() {
        isLoading = true
        
        // Simulated podcast data - in real app, would load from API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            podcasts = [
                Podcast(
                    id: "1",
                    title: "Music & Mind",
                    host: "Dr. Sarah Chen",
                    coverImage: "podcast_cover_1",
                    episodes: [
                        Episode(id: "1", title: "How Music Affects Mood", podcastTitle: "Music & Mind", duration: 45),
                        Episode(id: "2", title: "The Science of Playlists", podcastTitle: "Music & Mind", duration: 38)
                    ]
                ),
                Podcast(
                    id: "2", 
                    title: "Mixtape Stories",
                    host: "James Wilson",
                    coverImage: "podcast_cover_2",
                    episodes: [
                        Episode(id: "3", title: "Creating the Perfect Mix", podcastTitle: "Mixtape Stories", duration: 52),
                        Episode(id: "4", title: "Evolution of Mixtapes", podcastTitle: "Mixtape Stories", duration: 41)
                    ]
                ),
                Podcast(
                    id: "3",
                    title: "AI & Music",
                    host: "Tech Beats Team",
                    coverImage: "podcast_cover_3",
                    episodes: [
                        Episode(id: "5", title: "AI Music Generation", podcastTitle: "AI & Music", duration: 48),
                        Episode(id: "6", title: "Future of Music Creation", podcastTitle: "AI & Music", duration: 35)
                    ]
                )
            ]
            isLoading = false
        }
    }
}

// Supporting Models
struct Podcast: Identifiable {
    let id: String
    let title: String
    let host: String
    let coverImage: String
    let episodes: [Episode]
}

struct Episode: Identifiable {
    let id: String
    let title: String
    let podcastTitle: String
    let duration: Int
}

// UI Components
struct FeaturedPodcastCard: View {
    let podcast: Podcast
    let mood: Mood
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header image
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(mood.color.opacity(0.15))
                    .frame(height: 160)
                
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Featured")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(mood.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(mood.color.opacity(0.15))
                            )
                        
                        Text(podcast.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(podcast.host)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(mood.color)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "play.fill")
                                .foregroundColor(.white)
                        )
                }
                .padding()
            }
            
            // Latest episodes preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Latest Episodes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(podcast.episodes.prefix(2), id: \.id) { episode in
                    HStack {
                        Text(episode.title)
                            .font(.callout)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(episode.duration) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
        )
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? color : Color(.systemGray6))
                )
        }
    }
}
