import SwiftUI
import CoreData

struct LibraryView: View {
    @Environment(\.managedObjectContext) var moc
    @FetchRequest(
        entity: MixTape.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \MixTape.lastPlayedDate, ascending: false)]
    ) var mixtapes: FetchedResults<MixTape>
    
    var aiService: AIIntegrationService
    @State private var showingNewMixtapeSheet = false
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .grid
    
    enum ViewMode {
        case grid
        case list
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Mood-based recommendations
                if aiService.moodEngine.moodConfidence > 0.6 {
                    MoodRecommendationsSection(aiService: aiService)
                }
                
                // Main content
                VStack(alignment: .leading, spacing: 16) {
                    // Library header with controls
                    HStack {
                        Text("Your Library")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        ViewModeButton(viewMode: $viewMode)
                        
                        Button(action: { showingNewMixtapeSheet = true }) {
                            Label("Create Mixtape", systemImage: "plus.circle.fill")
                        }
                    }
                    .padding(.horizontal)
                    
                    if mixtapes.isEmpty {
                        EmptyLibraryView(showingNewMixtapeSheet: $showingNewMixtapeSheet)
                    } else {
                        Group {
                            switch viewMode {
                            case .grid:
                                MixtapeGridView(mixtapes: mixtapes, aiService: aiService)
                            case .list:
                                MixtapeListView(mixtapes: mixtapes, aiService: aiService)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .searchable(text: $searchText, prompt: "Search mixtapes")
        .sheet(isPresented: $showingNewMixtapeSheet) {
            NewMixTapeView(isPresented: $showingNewMixtapeSheet, aiService: aiService)
        }
    }
}

// MARK: - Supporting Views

struct MoodRecommendationsSection: View {
    var aiService: AIIntegrationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("For Your \(aiService.moodEngine.currentMood.rawValue) Mood", 
                      systemImage: aiService.moodEngine.currentMood.systemIcon)
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    aiService.trackInteraction(type: "refresh_mood_recommendations")
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(aiService.moodEngine.getMoodBasedRecommendations(), id: \.wrappedTitle) { mixtape in
                        MoodMixtapeCard(mixtape: mixtape, aiService: aiService)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct MoodMixtapeCard: View {
    let mixtape: MixTape
    let aiService: AIIntegrationService
    
    var body: some View {
        NavigationLink(value: mixtape) {
            VStack(alignment: .leading, spacing: 8) {
                // Cover art
                AsyncImage(url: URL(string: mixtape.wrappedUrl)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.secondary)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 140, height: 140)
                .cornerRadius(12)
                
                Text(mixtape.wrappedTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(mixtape.numberOfSongs) songs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 140)
        }
        .buttonStyle(.plain)
    }
}

struct ViewModeButton: View {
    @Binding var viewMode: LibraryView.ViewMode
    
    var body: some View {
        Button(action: { viewMode = viewMode == .grid ? .list : .grid }) {
            Image(systemName: viewMode == .grid ? "list.dash" : "square.grid.2x2")
        }
    }
}

struct EmptyLibraryView: View {
    @Binding var showingNewMixtapeSheet: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Your Library is Empty")
                .font(.headline)
            
            Text("Create your first mixtape to start organizing your music")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingNewMixtapeSheet = true }) {
                Label("Create Mixtape", systemImage: "plus")
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MixtapeGridView: View {
    var mixtapes: FetchedResults<MixTape>
    var aiService: AIIntegrationService
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(mixtapes, id: \.wrappedTitle) { mixtape in
                MoodMixtapeCard(mixtape: mixtape, aiService: aiService)
            }
        }
    }
}

struct MixtapeListView: View {
    var mixtapes: FetchedResults<MixTape>
    var aiService: AIIntegrationService
    
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(mixtapes, id: \.wrappedTitle) { mixtape in
                NavigationLink(value: NavigationItem.mixtapeDetail(mixtape)) {
                    HStack(spacing: 12) {
                        if let url = mixtape.wrappedUrl {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.1))
                                        .overlay(
                                            Image(systemName: "music.note")
                                                .foregroundColor(.secondary)
                                        )
                                }
                            }
                        } else {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .foregroundColor(.secondary)
                                )
                        }
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mixtape.wrappedTitle)
                                .font(.headline)
                            
                            Text("\(mixtape.numberOfSongs) songs")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if mixtape.mood != nil {
                            Circle()
                                .fill(aiService.moodEngine.currentMood.color)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
